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
                // Use async bytes sequence instead of readToEnd
                let outHandle = outPipe.fileHandleForReading
                let errHandle = errPipe.fileHandleForReading
                
                // Read output asynchronously
                var outData = Data()
                for try await byte in outHandle.bytes {
                    outData.append(byte)
                }
                
                var errData = Data()
                for try await byte in errHandle.bytes {
                    errData.append(byte)
                }
                
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

/// Retrieves the IPv4 address for a given network interface
/// - Parameter interfaceName: BSD name of the interface (e.g., "en0")
/// - Returns: IP address string, or empty string if not available
func getIPAddress(for interfaceName: String) async -> String {
    do {
        let cmd = "ifconfig \(interfaceName) | grep 'inet ' | grep -v inet6 | awk '{print $2}' | head -n1"
        let result = try await shell.run(cmd, timeout: 5)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    } catch {
        return ""
    }
}

/// Checks if an IP address is loopback or link-local
/// - Parameter ipAddress: The IP address to check
/// - Returns: true if the address should be filtered out
func isLoopbackOrLinkLocal(_ ipAddress: String) -> Bool {
    // Filter out loopback (127.x.x.x)
    if ipAddress.hasPrefix("127.") {
        return true
    }
    
    // Filter out link-local (169.254.x.x)
    if ipAddress.hasPrefix("169.254.") {
        return true
    }
    
    return false
}

/// Determines the appropriate SF Symbol icon for a network interface
/// - Parameters:
///   - localizedName: The localized display name (e.g., "Wi-Fi", "Ethernet")
///   - bsdName: The BSD device name (e.g., "en0", "en1")
/// - Returns: SF Symbol name for the interface type
func getIconForInterface(localizedName: String, bsdName: String) -> String {
    // Wi-Fi interfaces
    if localizedName.contains("Wi-Fi") || localizedName.contains("AirPort") {
        return "wifi"
    }
    
    // Thunderbolt interfaces
    if localizedName.contains("Thunderbolt") {
        return "bolt.fill"
    }
    
    // USB interfaces
    if localizedName.contains("USB") {
        return "cable.connector"
    }
    
    // Bluetooth PAN
    if localizedName.contains("Bluetooth") {
        return "bluetooth"
    }
    
    // Bridge interfaces
    if bsdName.hasPrefix("bridge") {
        return "network.badge.shield.half.filled"
    }
    
    // Default to ethernet for en0, en1, etc.
    if bsdName.hasPrefix("en") {
        return "cable.connector.horizontal"
    }
    
    // Generic network for everything else
    return "network"
}

/// Determines the appropriate SF Symbol icon for a storage volume
/// - Parameters:
///   - volumeURL: The URL of the mounted volume
///   - isInternal: Whether the volume is an internal drive
///   - isRemovable: Whether the volume is removable
///   - isLocal: Whether the volume is local (not network)
/// - Returns: SF Symbol name for the volume type
func getIconForVolume(volumeURL: URL, isInternal: Bool, isRemovable: Bool, isLocal: Bool) -> String {
    // Network volumes (SMB, AFP, NFS)
    if !isLocal {
        return "server.rack"
    }
    
    // Check if it's a disk image
    let path = volumeURL.path
    if path.contains("/Volumes/") {
        // Common disk image patterns
        if path.hasSuffix(".dmg") || path.hasSuffix(".sparsebundle") {
            return "opticaldiscdrive"
        }
    }
    
    // Removable drives (USB, Thunderbolt external drives)
    if isRemovable {
        return "externaldrive"
    }
    
    // Internal drives (system SSD/HDD)
    if isInternal {
        return "internaldrive"
    }
    
    // Default to external drive for everything else
    return "externaldrive"
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
    private var lastVolumeCount: Int = 0

    private var tick: Int = 0

    init() {
        Task {
            await buildEntries()
        }
        startTimer()
    }
    
    deinit {
        timer?.invalidate()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.tick = (self.tick + 1) % RefreshCadence.slow.rawValue
                await self.refreshAccordingToCadence()
            }
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

	private func buildEntries() async {
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

        // Network interfaces - only show active interfaces with IP addresses
        // First, collect all interfaces and check which ones have IPs
        let allInterfaces = SCNetworkInterfaceCopyAll() as NSArray
        
        for interface in allInterfaces {
            if let name = SCNetworkInterfaceGetBSDName(interface as! SCNetworkInterface),
               let localizedName = SCNetworkInterfaceGetLocalizedDisplayName(interface as! SCNetworkInterface) {
                let bsd = name as String
                let loc = localizedName as String
                
                // Get IP address to check if interface is active
                let ipAddress = await getIPAddress(for: bsd)
                
                // Skip interfaces without IP or with loopback/link-local addresses
                guard !ipAddress.isEmpty,
                      !isLoopbackOrLinkLocal(ipAddress) else {
                    continue
                }
                
                // Determine appropriate icon based on interface type
                let iconName = getIconForInterface(localizedName: loc, bsdName: bsd)
                let cadenceValue: RefreshCadence = (loc == "Wi-Fi") ? .medium : .slow

                statusEntries.append(StatusEntry(
                    id: statusEntries.count,
                    name: "\(loc) (\(bsd))",
                    category: "Network",
                    cadence: cadenceValue,
                    commandValue: {
                        let ip = await getIPAddress(for: bsd)
                        return ip.isEmpty ? "No IP" : ip
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
            icon: Image(systemName: "battery.100percent")
        ))

        // Storage - dynamically discover all mounted volumes
        let volumeKeys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeIsInternalKey,
            .volumeIsLocalKey,
            .volumeIsRemovableKey,
            .volumeIsEjectableKey,
            .volumeIsReadOnlyKey,
            .volumeIsBrowsableKey,
            .volumeSupportsVolumeSizesKey
        ]
        
        if let volumes = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: volumeKeys,
            options: [.skipHiddenVolumes]
        ) {
            // Update volume count for change detection
            lastVolumeCount = volumes.count
            
            for volumeURL in volumes {
                // Get volume properties
                guard let resourceValues = try? volumeURL.resourceValues(forKeys: Set(volumeKeys)) else {
                    continue
                }
                
                let volumeName = resourceValues.volumeName ?? "Unknown Volume"
                let isInternal = resourceValues.volumeIsInternal ?? false
                let isRemovable = resourceValues.volumeIsRemovable ?? false
                let isLocal = resourceValues.volumeIsLocal ?? true
				_ = resourceValues.volumeIsReadOnly ?? false
                let isBrowsable = resourceValues.volumeIsBrowsable ?? true
                let supportsVolumeSizes = resourceValues.volumeSupportsVolumeSizes ?? true
                
                // Skip volumes that don't support capacity queries
                // This catches backup drives, recovery partitions, and special volumes
                guard supportsVolumeSizes else {
                    continue
                }
                
                // Skip non-browsable volumes (system volumes, recovery partitions, etc.)
                guard isBrowsable else {
                    continue
                }
                
                // Skip special APFS system volumes by name (these are always present)
                if volumeName == "Data" || 
                   volumeName == "Preboot" || 
                   volumeName == "Recovery" ||
                   volumeName == "VM" {
                    continue
                }
                
                // Determine appropriate icon
                let iconName = getIconForVolume(
                    volumeURL: volumeURL,
                    isInternal: isInternal,
                    isRemovable: isRemovable,
                    isLocal: isLocal
                )
                
                // Create storage entry for this volume
                statusEntries.append(StatusEntry(
                    id: statusEntries.count,
                    name: "\(volumeName)",
                    category: "Storage",
                    cadence: .slow,
                    commandValue: {
                        let info = getDiskSpaceInfo(for: volumeURL)
                        return "\(info.usedCapacity) | \(info.availableCapacity) | \(info.totalCapacity)"
                    },
                    icon: Image(systemName: iconName)
                ))
            }
        }
        
        Task { await self.populateInitialValues() }
    }

    // Async refresh that can be called by views
    func refresh() async {
        // For now, entries compute their values lazily when invoked by the UI.
        // If you want to precompute and cache values, you could evaluate each commandValue here and publish a concrete list.
        await buildEntries()
    }

    private func shouldRefresh(entry: StatusEntry, atTick tick: Int) -> Bool {
        return tick % entry.cadence.rawValue == 0
    }

    private func anyNeedingRefresh(atTick tick: Int) -> Bool {
        return statusEntries.contains { shouldRefresh(entry: $0, atTick: tick) }
    }

    private func refreshAccordingToCadence() async {
        if statusEntries.isEmpty { 
            await buildEntries()
        }
        
        // Check if volumes have changed (every 10 seconds)
        if tick % RefreshCadence.medium.rawValue == 0 {
            await checkVolumeChanges()
        }
        
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
    
    /// Checks if the number of mounted volumes has changed and rebuilds entries if needed
    private func checkVolumeChanges() async {
        let currentVolumeCount = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: nil,
            options: [.skipHiddenVolumes]
        )?.count ?? 0
        
        // If volume count changed, rebuild all entries
        if currentVolumeCount != lastVolumeCount {
            lastVolumeCount = currentVolumeCount
            await buildEntries()
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

