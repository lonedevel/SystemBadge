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

        func terminateProcess() {
            if process.isRunning {
                process.terminate()
                // If it doesn't terminate quickly, escalate
                DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                    guard process.isRunning else { return }
                    process.interrupt()
                    DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                        guard process.isRunning else { return }
                        #if canImport(Darwin)
                        Darwin.kill(process.processIdentifier, SIGKILL)
                        #endif
                    }
                }
            }
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
                terminateProcess()
                throw error
            }
        }
    }
}

// Legacy sync wrappers (safe): return empty string on error instead of crashing the app
private let shell = Shell()

func shellCmd(cmd: String, timeout: TimeInterval = 5) -> String {
    // Prefer async usage; this sync wrapper is best-effort and should not be used from the main thread.
    // It awaits using Task and blocks until completion via a semaphore to preserve existing call sites,
    // but returns an empty string on error to avoid Objective-C exceptions.
    let sem = DispatchSemaphore(value: 0)
    var result = ""
    Task {
        do { result = try await shell.run(cmd, timeout: timeout) } catch { result = "" }
        sem.signal()
    }
    sem.wait()
    return result
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
                let output = shellCmd(cmd: "hostname -f").trimmingCharacters(in: .whitespacesAndNewlines)
                return output
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
                        let cmd = "ifconfig \(bsd) | grep inet | grep -v inet6 | cut -d' ' -f2 | tail -n1"
                        return shellCmd(cmd: cmd).trimmingCharacters(in: .whitespacesAndNewlines)
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
                let cmd = "curl --silent ipecho.net/plain ; echo"
                return shellCmd(cmd: cmd).trimmingCharacters(in: .whitespacesAndNewlines)
            },
            icon: Image(systemName: "network")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "CPU Type",
            category: "System",
            cadence: .slow,
            commandValue: {
                let cmd = "sysctl -n machdep.cpu.brand_string |awk '$1=$1' | sed 's/([A-Z]{1,2})//g'"
                return shellCmd(cmd: cmd).trimmingCharacters(in: .whitespacesAndNewlines)
            },
            icon: Image(systemName: "cpu")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "CPU cores/threads",
            category: "System",
            cadence: .slow,
            commandValue: {
                let cmd = "echo `sysctl -n hw.physicalcpu` '/' `sysctl -n hw.logicalcpu`"
                return shellCmd(cmd: cmd).trimmingCharacters(in: .whitespacesAndNewlines)
            },
            icon: Image(systemName: "cpu")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "RAM",
            category: "System",
            cadence: .slow,
            commandValue: {
                let cmd = "expr `sysctl -n hw.memsize` / 1073741824"
                let val = shellCmd(cmd: cmd).trimmingCharacters(in: .whitespacesAndNewlines)
                return val.isEmpty ? "" : "\(val) GB"
            },
            icon: Image(systemName: "memorychip")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "Operating System",
            category: "System",
            cadence: .slow,
            commandValue: {
                let cmd = "echo `sw_vers -productName` `sw_vers -productVersion`"
                return shellCmd(cmd: cmd).trimmingCharacters(in: .whitespacesAndNewlines)
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
            commandValue: {
                let info = getDiskSpaceInfo(for: URL(fileURLWithPath: "/Volumes/Backup-1"))
                return "\(info.usedCapacity) | \(info.availableCapacity) | \(info.totalCapacity)"
            },
            icon: Image(systemName: "cylinder.fill")
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
        let seconds = time % 60
        let minutes = (time / 60) % 60
        let hours = (time / 3600) % 24
        let days = (time / 84000)
        return String(format: "%02d d %0.2d h %0.2d m %0.2d s", days, hours, minutes, seconds)
    }
}

