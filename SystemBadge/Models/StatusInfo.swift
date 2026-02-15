import Foundation
import SystemConfiguration
import SwiftUI

enum RefreshCadence: Int {
    case fast = 1      // every 1s
    case medium = 10   // every 10s
    case slow = 60     // every 60s
}

// MARK: - Async Shell runner
actor Shell {
    func run(_ command: String, timeout: TimeInterval = 5) async throws -> String {
        let process = Process()
        // Use a login shell so PATH and shell expansions work when launched by launchd
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        try process.run()

        /// Gracefully terminates the process with escalating signals
        func terminateProcess() async {
            guard process.isRunning else { return }
            let pid = process.processIdentifier
            
            // Step 1: Try SIGTERM (graceful termination)
            process.terminate()
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            // Step 2: If still running and PID matches, try SIGINT (interrupt)
            guard process.isRunning, process.processIdentifier == pid else { return }
            process.interrupt()
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            // Step 3: If still running and PID matches, use SIGKILL (force kill)
            guard process.isRunning, process.processIdentifier == pid else { return }
            #if canImport(Darwin)
            Darwin.kill(pid, SIGKILL)
            #endif
        }

        let runToCompletion: () async throws -> String = {
            #if compiler(>=6.0)
            if #available(macOS 13.0, *) {
                let outData = try await outPipe.fileHandleForReading.readToEnd() ?? Data()
                let errData = try await errPipe.fileHandleForReading.readToEnd() ?? Data()
                // Await process termination asynchronously instead of blocking
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    process.terminationHandler = { _ in
                        continuation.resume()
                    }
                }
                let statusCode = Int(process.terminationStatus)
                if statusCode != 0 {
                    let stderr = String(data: errData, encoding: .utf8) ?? ""
                    throw NSError(domain: "Shell", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Command failed", "stderr": stderr, "command": command])
                }
                return String(data: outData, encoding: .utf8) ?? ""
            }
            #endif
            let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                process.terminationHandler = { _ in continuation.resume() }
            }
            let statusCode = Int(process.terminationStatus)
            if statusCode != 0 {
                let stderr = String(data: errData, encoding: .utf8) ?? ""
                throw NSError(domain: "Shell", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Command failed", "stderr": stderr, "command": command])
            }
            return String(data: outData, encoding: .utf8) ?? ""
        }

        // Race: process completion vs timeout
        return try await withThrowingTaskGroup(of: String.self) { group in
            // Task 1: read output and wait for process exit
            group.addTask {
                return try await runToCompletion()
            }
            // Task 2: timeout
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
				throw NSError(domain: "Shell", code: Int(ETIMEDOUT), userInfo: [NSLocalizedDescriptionKey: "Command timed out after \(timeout)s", "command": command])
            }

            do {
                let result = try await group.next()!
                group.cancelAll()
                return result
            } catch {
                group.cancelAll()
                await terminateProcess()
                throw error
            }
        }
    }
}

// Legacy sync wrappers (safe): return empty string on error instead of crashing the app
private let shell = Shell()

@available(*, deprecated, message: "Use shell.run() directly with async/await")
func shellCmd(cmd: String, timeout: TimeInterval = 5) -> String {
    // Legacy sync wrapper for backward compatibility
    // This blocks the calling thread, so avoid using it when possible
    let sem = DispatchSemaphore(value: 0)
    var result = ""
    Task {
        do { result = try await shell.run(cmd, timeout: timeout) } catch { result = "" }
        sem.signal()
    }
    sem.wait()
    return result
}

// MARK: - Helper Functions

/// Retrieves the public IP address with fallback services
/// - Returns: Public IP address string, or "Unavailable" if all services fail
func getPublicIPAddress() async -> String {
    let services = [
        "https://api.ipify.org",
        "https://icanhazip.com",
        "https://ipecho.net/plain"
    ]
    
    for service in services {
        do {
            let result = try await shell.run("curl --silent --max-time 3 '\(service)'", timeout: 5)
            let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Validate it looks like an IP address (basic IPv4 regex)
            if !trimmed.isEmpty,
               trimmed.range(of: #"^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$"#, options: .regularExpression) != nil {
                return trimmed
            }
        } catch {
            // Try next service
            continue
        }
    }
    
    return "Unavailable"
}

// MARK: - Status Model
struct StatusEntry: Identifiable {
    var id: Int
    let name: String
    let category: String
    let cadence: RefreshCadence
    var commandValue: () async -> String
    let icon: Image
    var value: String = ""

    func evaluate() async -> String {
        return await commandValue()
    }
}

@MainActor
class StatusInfo: ObservableObject {
    @Published var statusEntries: [StatusEntry] = []
    private var timer: Timer?
    
    // Configurable settings
    @AppStorage("backupVolumePath") private var backupVolumePath = "/Volumes/Backup-1"

    private var tick: Int = 0

    init() {
        buildEntries()
        startTimer()
    }
    
    deinit {
        timer?.invalidate()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.tick = (self.tick + 1) % RefreshCadence.slow.rawValue
            Task { await self.refreshAccordingToCadence() }
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func buildEntries() {
        statusEntries = []

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "Current Date",
            category: "General",
            cadence: .medium,
            commandValue: { Date().formatted(date: .complete, time: .omitted) },
            icon: Image(systemName: "calendar")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "Current Time",
            category: "General",
            cadence: .fast,
            commandValue: { Date().formatted(date: .omitted, time: .complete) },
            icon: Image(systemName: "clock")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "Short Hostname",
            category: "General",
            cadence: .medium,
            commandValue: { Host.current().localizedName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" },
            icon: Image(systemName: "desktopcomputer.and.arrow.down")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "FQDN Hostname",
            category: "Network",
            cadence: .slow,
            commandValue: {
                do {
                    let output = try await shell.run("hostname -f", timeout: 5)
                    return output.trimmingCharacters(in: .whitespacesAndNewlines)
                } catch {
                    return ""
                }
            },
            icon: Image(systemName: "desktopcomputer.and.arrow.down")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "Username",
            category: "General",
            cadence: .medium,
            commandValue: { "\(NSUserName()) ( \(NSFullUserName()) )".trimmingCharacters(in: .whitespacesAndNewlines) },
            icon: Image(systemName: "person")
        ))

        // Network interfaces
        for interface in SCNetworkInterfaceCopyAll() as NSArray {
            if let name = SCNetworkInterfaceGetBSDName(interface as! SCNetworkInterface),
               let localizedName = SCNetworkInterfaceGetLocalizedDisplayName(interface as! SCNetworkInterface) {
                let bsd = name as String
                let loc = localizedName as String
                let iconName = (loc == "Wi-Fi") ? "wifi" : "network"
                let cadenceValue: RefreshCadence = (loc == "Wi-Fi") ? .medium : .slow

                statusEntries.append(StatusEntry(
                    id: statusEntries.count,
                    name: "\(loc) (\(bsd))",
                    category: "Network",
                    cadence: cadenceValue,
                    commandValue: {
                        do {
                            let cmd = "ifconfig \(bsd) | grep inet | grep -v inet6 | cut -d' ' -f2 | tail -n1"
                            let result = try await shell.run(cmd, timeout: 5)
                            return result.trimmingCharacters(in: .whitespacesAndNewlines)
                        } catch {
                            return ""
                        }
                    },
                    icon: Image(systemName: iconName)
                ))
            }
        }

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "Public IP Address",
            category: "Network",
            cadence: .slow,
            commandValue: {
                return await getPublicIPAddress()
            },
            icon: Image(systemName: "network")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "CPU Type",
            category: "System",
            cadence: .slow,
            commandValue: {
                do {
                    let cmd = "sysctl -n machdep.cpu.brand_string |awk '$1=$1' | sed 's/([A-Z]{1,2})//g'"
                    let result = try await shell.run(cmd, timeout: 5)
                    return result.trimmingCharacters(in: .whitespacesAndNewlines)
                } catch {
                    return ""
                }
            },
            icon: Image(systemName: "cpu")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "CPU cores/threads",
            category: "System",
            cadence: .slow,
            commandValue: {
                do {
                    let cmd = "echo `sysctl -n hw.physicalcpu` '/' `sysctl -n hw.logicalcpu`"
                    let result = try await shell.run(cmd, timeout: 5)
                    return result.trimmingCharacters(in: .whitespacesAndNewlines)
                } catch {
                    return ""
                }
            },
            icon: Image(systemName: "cpu")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "RAM",
            category: "System",
            cadence: .slow,
            commandValue: {
                do {
                    let cmd = "expr `sysctl -n hw.memsize` / 1073741824"
                    let result = try await shell.run(cmd, timeout: 5)
                    let val = result.trimmingCharacters(in: .whitespacesAndNewlines)
                    return val.isEmpty ? "" : "\(val) GB"
                } catch {
                    return ""
                }
            },
            icon: Image(systemName: "memorychip")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "Operating System",
            category: "System",
            cadence: .slow,
            commandValue: {
                do {
                    let cmd = "echo `sw_vers -productName` `sw_vers -productVersion`"
                    let result = try await shell.run(cmd, timeout: 5)
                    return result.trimmingCharacters(in: .whitespacesAndNewlines)
                } catch {
                    return ""
                }
            },
            icon: Image(systemName: "macwindow.on.rectangle")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "System Uptime",
            category: "General",
            cadence: .fast,
            commandValue: { ProcessInfo.processInfo.systemUptime.stringFromTimeInterval().trimmingCharacters(in: .whitespacesAndNewlines) },
            icon: Image(systemName: "deskclock")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "Battery Health",
            category: "Power",
            cadence: .slow,
            commandValue: { getBatteryHealth() ?? "Unknown" },
            icon: Image(systemName: "bolt")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "Battery Percentage",
            category: "Power",
            cadence: .medium,
            commandValue: {
                if let pct = getBatteryPercentageHealth() {
                    let value: Double = pct <= 1.0 ? pct * 100.0 : pct
                    if value.rounded(.towardZero) == value {
                        return String(format: "%.0f%%", value)
                    } else {
                        return String(format: "%.1f%%", value)
                    }
                } else {
                    return "Unknown"
                }
            },
            icon: Image("battery.75percent")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "Used | Available | Total Capacity (root)",
            category: "Storage",
            cadence: .slow,
            commandValue: {
                let rootDiskInfo = getDiskSpaceInfo(for: URL(fileURLWithPath: "/"))
                return "\(rootDiskInfo.usedCapacity) | \(rootDiskInfo.availableCapacity) | \(rootDiskInfo.totalCapacity)"
            },
            icon: Image(systemName: "cylinder.fill")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "Used | Available | Total Capacity (backup)",
            category: "Storage",
            cadence: .slow,
            commandValue: { [weak self] in
                guard let self = self else { return "n/a | n/a | n/a" }
                let volumePath = self.backupVolumePath
                
                // Check if the volume exists
                let fileManager = FileManager.default
                guard fileManager.fileExists(atPath: volumePath) else {
                    return "Volume not mounted"
                }
                
                let info = getDiskSpaceInfo(for: URL(fileURLWithPath: volumePath))
                return "\(info.usedCapacity) | \(info.availableCapacity) | \(info.totalCapacity)"
            },
            icon: Image(systemName: "externaldrive.fill")
        ))
        
        Task { await self.populateInitialValues() }
    }

    // Async refresh that can be called by views
    func refresh() async {
        // For now, entries compute their values lazily when invoked by the UI.
        // If you want to precompute and cache values, you could evaluate each commandValue here and publish a concrete list.
        buildEntries()
    }

    private func shouldRefresh(entry: StatusEntry, atTick tick: Int) -> Bool {
        return tick % entry.cadence.rawValue == 0
    }

    private func anyNeedingRefresh(atTick tick: Int) -> Bool {
        return statusEntries.contains { shouldRefresh(entry: $0, atTick: tick) }
    }

    private func refreshAccordingToCadence() async {
        if statusEntries.isEmpty { buildEntries() }
        var updated = self.statusEntries
        var changed = false
        for idx in updated.indices {
            let entry = updated[idx]
            if shouldRefresh(entry: entry, atTick: tick) {
                let newValue = await entry.commandValue()
                if newValue != entry.value {
                    updated[idx].value = newValue
                    changed = true
                }
            }
        }
        if changed {
            self.statusEntries = updated
        }
    }

    private func populateInitialValues() async {
        var updated = self.statusEntries
        for idx in updated.indices {
            let newValue = await updated[idx].commandValue()
            updated[idx].value = newValue
        }
        // Publish once after computing all values
        self.statusEntries = updated
    }
}

extension TimeInterval {
    func stringFromTimeInterval() -> String {
        let time = NSInteger(self)
        
        // Constants for time calculations
        let secondsPerMinute = 60
        let secondsPerHour = 3600
        let secondsPerDay = 86400
        
        let days = time / secondsPerDay
        let hours = (time % secondsPerDay) / secondsPerHour
        let minutes = (time % secondsPerHour) / secondsPerMinute
        let seconds = time % secondsPerMinute
        
        return String(format: "%02dd %02dh %02dm %02ds", days, hours, minutes, seconds)
    }
}

