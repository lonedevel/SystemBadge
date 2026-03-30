import Foundation
import SystemConfiguration
import SwiftUI
import CoreWLAN
import CoreLocation

enum RefreshCadence: Int {
    case fast = 1      // every 1s
    case medium = 10   // every 10s
    case slow = 60     // every 60s
}

enum DisplayStyle {
    case text
    case percentBar
    case ratePair
    case sparkline
}

struct MetricSample {
    let text: String
    let primary: Double?
    let secondary: Double?

    static func text(_ value: String) -> MetricSample {
        MetricSample(text: value, primary: nil, secondary: nil)
    }
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

// MARK: - Additional Metrics Helpers

func readKeyValue(_ text: String) -> [String: String] {
    var result: [String: String] = [:]
    for line in text.split(whereSeparator: \.isNewline) {
        let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        if parts.count == 2 {
            result[String(parts[0])] = String(parts[1])
        }
    }
    return result
}

func parsePmsetBatt(_ text: String) -> (source: String, status: String, time: String) {
    var source = "Unknown"
    var status = "Unknown"
    var time = "Unknown"
    for line in text.split(whereSeparator: \.isNewline) {
        if line.contains("Now drawing from") {
            if let start = line.firstIndex(of: "'"), let end = line.lastIndex(of: "'"), start < end {
                source = String(line[line.index(after: start)..<end])
            }
        }
        if line.contains("%") {
            let parts = line.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count >= 2 {
                status = parts[1]
            }
            if parts.count >= 3 {
                time = parts[2]
            }
        }
    }
    return (source, status, time)
}

func thermalStateText() -> String {
    switch ProcessInfo.processInfo.thermalState {
    case .nominal:
        return "Nominal"
    case .fair:
        return "Fair"
    case .serious:
        return "Serious"
    case .critical:
        return "Critical"
    @unknown default:
        return "Unknown"
    }
}

func timeSince(date: Date) -> String {
    let interval = Date().timeIntervalSince(date)
    return interval.stringFromTimeInterval()
}

func wifiDeviceName(from text: String) -> String? {
    var lines = text.split(whereSeparator: \.isNewline).map { String($0) }
    while !lines.isEmpty {
        if lines[0].contains("Hardware Port: Wi-Fi") || lines[0].contains("Hardware Port: AirPort") {
            if lines.count >= 2, lines[1].contains("Device:") {
                let parts = lines[1].split(separator: ":").map { $0.trimmingCharacters(in: .whitespaces) }
                if parts.count == 2, !parts[1].isEmpty {
                    return parts[1]
                }
            }
        }
        lines.removeFirst()
    }
    return nil
}

func parseAirportInfoFromSystemProfiler(_ text: String) -> [String: String] {
    var result: [String: String] = [:]
    var inCurrentNetwork = false
    var currentSSID: String?
    var ssidIndent: Int?
    for rawLine in text.split(whereSeparator: \.isNewline) {
        let line = String(rawLine)
        let indent = line.prefix { $0 == " " }.count
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("Current Network Information:") {
            inCurrentNetwork = true
            continue
        }
        if inCurrentNetwork, trimmed.hasPrefix("Other Local Wi-Fi Networks:") {
            break
        }
        guard inCurrentNetwork else { continue }
        if trimmed.isEmpty { continue }
        if trimmed.hasSuffix(":"), !trimmed.contains(" ") {
            // SSID line (often no spaces)
            let ssid = String(trimmed.dropLast())
            currentSSID = ssid
            ssidIndent = indent
            result["SSID"] = ssid
            continue
        }
        if let ssidIndent, indent <= ssidIndent, currentSSID != nil, trimmed.hasSuffix(":") {
            // New section after SSID
            break
        }
        if trimmed.contains(":") {
            let parts = trimmed.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 {
                result[String(parts[0])] = String(parts[1])
            }
        }
    }
    return result
}

func getWiFiSSIDCoreWLAN() -> String? {
    let client = CWWiFiClient.shared()
    return client.interface()?.ssid()
}

// MARK: - Status Model
struct StatusEntry: Identifiable {
    var id: Int
    let name: String
    let category: String
    let cadence: RefreshCadence
    let displayStyle: DisplayStyle
    let unit: String?
    let scaleMode: SparklineScaleMode?
    var commandValue: () async -> MetricSample
    let icon: Image
    var value: String = ""
    var primaryValue: Double? = nil
    var secondaryValue: Double? = nil
    var history: [Double] = []

    func evaluate() async -> MetricSample {
        return await commandValue()
    }
}

@MainActor
class StatusInfo: ObservableObject {
    @Published var statusEntries: [StatusEntry] = []
    private var timer: Timer?
    private var lastVolumeCount: Int = 0
    private let performanceSampler = PerformanceSampler()
    private let maxHistoryCount = 60
    private var wifiProfilerCache: (timestamp: Date, info: [String: String])?
    private var locationManager: CLLocationManager?

    private var tick: Int = 0

    init() {
        requestLocationAccess()
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

    private func requestLocationAccess() {
        let manager = CLLocationManager()
        locationManager = manager
        manager.requestWhenInUseAuthorization()
    }

    private func getWiFiProfilerInfo() async -> [String: String]? {
        if let cache = wifiProfilerCache, Date().timeIntervalSince(cache.timestamp) < 15 {
            return cache.info
        }
        do {
            let output = try await shell.run("system_profiler SPAirPortDataType", timeout: 10)
            let info = parseAirportInfoFromSystemProfiler(output)
            wifiProfilerCache = (Date(), info)
            return info
        } catch {
            return nil
        }
    }

    private func buildEntries() async {
        statusEntries = []
        let sampler = performanceSampler
        let wifiDevice: String
        do {
            let ports = try await shell.run("networksetup -listallhardwareports", timeout: 5)
            wifiDevice = wifiDeviceName(from: ports) ?? "en0"
        } catch {
            wifiDevice = "en0"
        }

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "Current Date",
            category: "General",
            cadence: .medium,
            displayStyle: .text,
            unit: nil,
            scaleMode: nil,
            commandValue: { MetricSample.text(Date().formatted(date: .complete, time: .omitted)) },
            icon: Image(systemName: "calendar")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "Current Time",
            category: "General",
            cadence: .fast,
            displayStyle: .text,
            unit: nil,
            scaleMode: nil,
            commandValue: { MetricSample.text(Date().formatted(date: .omitted, time: .complete)) },
            icon: Image(systemName: "clock")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "Short Hostname",
            category: "General",
            cadence: .medium,
            displayStyle: .text,
            unit: nil,
            scaleMode: nil,
            commandValue: { MetricSample.text(Host.current().localizedName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "") },
            icon: Image(systemName: "desktopcomputer.and.arrow.down")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "FQDN Hostname",
            category: "Network",
            cadence: .slow,
            displayStyle: .text,
            unit: nil,
            scaleMode: nil,
            commandValue: {
                do {
                    let output = try await shell.run("hostname -f", timeout: 5)
                    return MetricSample.text(output.trimmingCharacters(in: .whitespacesAndNewlines))
                } catch {
                    return MetricSample.text("")
                }
            },
            icon: Image(systemName: "desktopcomputer.and.arrow.down")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "Username",
            category: "General",
            cadence: .medium,
            displayStyle: .text,
            unit: nil,
            scaleMode: nil,
            commandValue: { MetricSample.text("\(NSUserName()) ( \(NSFullUserName()) )".trimmingCharacters(in: .whitespacesAndNewlines)) },
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
                    displayStyle: .text,
                    unit: nil,
                    scaleMode: nil,
                    commandValue: {
                        let ip = await getIPAddress(for: bsd)
                        return MetricSample.text(ip.isEmpty ? "No IP" : ip)
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
            displayStyle: .text,
            unit: nil,
            scaleMode: nil,
            commandValue: {
                return MetricSample.text(await getPublicIPAddress())
            },
            icon: Image(systemName: "network")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "Wi-Fi SSID",
            category: "Network",
            cadence: .medium,
            displayStyle: .text,
            unit: nil,
            scaleMode: nil,
            commandValue: { [weak self] in
                guard let self else { return MetricSample.text("Unavailable") }
                if let ssid = getWiFiSSIDCoreWLAN(), !ssid.isEmpty {
                    return MetricSample.text(ssid)
                }
                if let info = await self.getWiFiProfilerInfo(), let ssid = info["SSID"], !ssid.isEmpty {
                    return MetricSample.text(ssid)
                }
                do {
                    let output = try await shell.run("networksetup -getairportnetwork \(wifiDevice)", timeout: 5)
                    let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.contains("You are not associated") {
                        return MetricSample.text("Not connected")
                    }
                    if let range = trimmed.range(of: ":") {
                        return MetricSample.text(String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespaces))
                    }
                    return MetricSample.text(trimmed)
                } catch {
                    return MetricSample.text("Unavailable")
                }
            },
            icon: Image(systemName: "wifi")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "Wi-Fi Signal (RSSI / Noise)",
            category: "Network",
            cadence: .medium,
            displayStyle: .text,
            unit: nil,
            scaleMode: nil,
            commandValue: { [weak self] in
                guard let self else { return MetricSample.text("Unavailable") }
                if let info = await self.getWiFiProfilerInfo() {
                    if let signalNoise = info["Signal / Noise"], !signalNoise.isEmpty {
                        return MetricSample.text(signalNoise)
                    }
                    let rssi = info["RSSI"] ?? "n/a"
                    let noise = info["Noise"] ?? "n/a"
                    return MetricSample.text("\(rssi) / \(noise)")
                }
                return MetricSample.text("Unavailable")
            },
            icon: Image(systemName: "wifi")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "Wi-Fi Tx Rate",
            category: "Network",
            cadence: .medium,
            displayStyle: .text,
            unit: nil,
            scaleMode: nil,
            commandValue: { [weak self] in
                guard let self else { return MetricSample.text("Unavailable") }
                if let info = await self.getWiFiProfilerInfo(), let rate = info["Transmit Rate"], !rate.isEmpty {
                    return MetricSample.text(rate)
                }
                return MetricSample.text("n/a")
            },
            icon: Image(systemName: "arrow.up.right.circle")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "Wi-Fi Security",
            category: "Network",
            cadence: .slow,
            displayStyle: .text,
            unit: nil,
            scaleMode: nil,
            commandValue: { [weak self] in
                guard let self else { return MetricSample.text("Unavailable") }
                if let info = await self.getWiFiProfilerInfo(), let security = info["Security"], !security.isEmpty {
                    return MetricSample.text(security)
                }
                return MetricSample.text("n/a")
            },
            icon: Image(systemName: "lock")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "CPU Type",
            category: "System",
            cadence: .slow,
            displayStyle: .text,
            unit: nil,
            scaleMode: nil,
            commandValue: {
                do {
                    let cmd = "sysctl -n machdep.cpu.brand_string |awk '$1=$1' | sed 's/([A-Z]{1,2})//g'"
                    let result = try await shell.run(cmd, timeout: 5)
                    return MetricSample.text(result.trimmingCharacters(in: .whitespacesAndNewlines))
                } catch {
                    return MetricSample.text("")
                }
            },
            icon: Image(systemName: "cpu")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "CPU cores/threads",
            category: "System",
            cadence: .slow,
            displayStyle: .text,
            unit: nil,
            scaleMode: nil,
            commandValue: {
                do {
                    let cmd = "echo `sysctl -n hw.physicalcpu` '/' `sysctl -n hw.logicalcpu`"
                    let result = try await shell.run(cmd, timeout: 5)
                    return MetricSample.text(result.trimmingCharacters(in: .whitespacesAndNewlines))
                } catch {
                    return MetricSample.text("")
                }
            },
            icon: Image(systemName: "cpu")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "RAM",
            category: "System",
            cadence: .slow,
            displayStyle: .text,
            unit: nil,
            scaleMode: nil,
            commandValue: {
                do {
                    let cmd = "expr `sysctl -n hw.memsize` / 1073741824"
                    let result = try await shell.run(cmd, timeout: 5)
                    let val = result.trimmingCharacters(in: .whitespacesAndNewlines)
                    return MetricSample.text(val.isEmpty ? "" : "\(val) GB")
                } catch {
                    return MetricSample.text("")
                }
            },
            icon: Image(systemName: "memorychip")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "Operating System",
            category: "System",
            cadence: .slow,
            displayStyle: .text,
            unit: nil,
            scaleMode: nil,
            commandValue: {
                do {
                    let cmd = "echo `sw_vers -productName` `sw_vers -productVersion`"
                    let result = try await shell.run(cmd, timeout: 5)
                    return MetricSample.text(result.trimmingCharacters(in: .whitespacesAndNewlines))
                } catch {
                    return MetricSample.text("")
                }
            },
            icon: Image(systemName: "macwindow.on.rectangle")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "System Uptime",
            category: "General",
            cadence: .fast,
            displayStyle: .text,
            unit: nil,
            scaleMode: nil,
            commandValue: { MetricSample.text(ProcessInfo.processInfo.systemUptime.stringFromTimeInterval().trimmingCharacters(in: .whitespacesAndNewlines)) },
            icon: Image(systemName: "deskclock")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "Battery Health",
            category: "Power",
            cadence: .slow,
            displayStyle: .text,
            unit: nil,
            scaleMode: nil,
            commandValue: { MetricSample.text(getBatteryHealth() ?? "Unknown") },
            icon: Image(systemName: "bolt")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "Battery Status",
            category: "Power",
            cadence: .medium,
            displayStyle: .text,
            unit: nil,
            scaleMode: nil,
            commandValue: {
                do {
                    let output = try await shell.run("pmset -g batt", timeout: 5)
                    let parsed = parsePmsetBatt(output)
                    return MetricSample.text("\(parsed.status) • \(parsed.time)")
                } catch {
                    return MetricSample.text("Unavailable")
                }
            },
            icon: Image(systemName: "battery.100percent")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "Power Source",
            category: "Power",
            cadence: .medium,
            displayStyle: .text,
            unit: nil,
            scaleMode: nil,
            commandValue: {
                do {
                    let output = try await shell.run("pmset -g batt", timeout: 5)
                    let parsed = parsePmsetBatt(output)
                    return MetricSample.text(parsed.source)
                } catch {
                    return MetricSample.text("Unavailable")
                }
            },
            icon: Image(systemName: "powerplug")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "Battery Cycle Count",
            category: "Power",
            cadence: .slow,
            displayStyle: .text,
            unit: nil,
            scaleMode: nil,
            commandValue: {
                do {
                    let output = try await shell.run("system_profiler SPPowerDataType | awk -F: '/Cycle Count/ {gsub(/ /, \"\", $2); print $2; exit}'", timeout: 5)
                    let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    return MetricSample.text(trimmed.isEmpty ? "n/a" : trimmed)
                } catch {
                    return MetricSample.text("Unavailable")
                }
            },
            icon: Image(systemName: "repeat")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "Power Mode",
            category: "Power",
            cadence: .slow,
            displayStyle: .text,
            unit: nil,
            scaleMode: nil,
            commandValue: {
                do {
                    let output = try await shell.run("pmset -g | awk '/lowpowermode/ {low=$2} /highpowermode/ {high=$2} END{print low\":\"high}'", timeout: 5)
                    let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    let parts = trimmed.split(separator: ":")
                    let low = (parts.count > 0 && parts[0] == "1") ? "On" : "Off"
                    let high = (parts.count > 1 && parts[1] == "1") ? "On" : "Off"
                    return MetricSample.text("Low: \(low) • High: \(high)")
                } catch {
                    return MetricSample.text("Unavailable")
                }
            },
            icon: Image(systemName: "bolt.badge.a")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "Battery Percentage",
            category: "Power",
            cadence: .medium,
            displayStyle: .percentBar,
            unit: "%",
            scaleMode: nil,
            commandValue: {
                if let pct = getBatteryPercentageHealth() {
                    let value: Double = pct <= 1.0 ? pct * 100.0 : pct
                    if value.rounded(.towardZero) == value {
                        return MetricSample(text: String(format: "%.0f%%", value), primary: value, secondary: nil)
                    } else {
                        return MetricSample(text: String(format: "%.1f%%", value), primary: value, secondary: nil)
                    }
                } else {
                    return MetricSample.text("Unknown")
                }
            },
            icon: Image(systemName: "battery.100percent")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "CPU Usage",
            category: "Performance",
            cadence: .fast,
            displayStyle: .sparkline,
            unit: "%",
            scaleMode: nil,
            commandValue: {
                if let cpu = await sampler.cpuUsagePercent() {
                    return MetricSample(text: String(format: "%.0f%%", cpu), primary: cpu, secondary: nil)
                }
                return MetricSample.text("n/a")
            },
            icon: Image(systemName: "waveform.path.ecg")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "Memory Usage",
            category: "Performance",
            cadence: .fast,
            displayStyle: .sparkline,
            unit: "%",
            scaleMode: nil,
            commandValue: {
                if let memory = await sampler.memoryUsagePercent() {
                    let formatter = ByteCountFormatter()
                    formatter.countStyle = .memory
                    let usedText = formatter.string(fromByteCount: Int64(memory.usedBytes))
                    let totalText = formatter.string(fromByteCount: Int64(memory.totalBytes))
                    let text = String(format: "%.0f%% (%@ / %@)", memory.percent, usedText, totalText)
                    return MetricSample(text: text, primary: memory.percent, secondary: nil)
                }
                return MetricSample.text("n/a")
            },
            icon: Image(systemName: "memorychip")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "Cached Files",
            category: "Performance",
            cadence: .fast,
            displayStyle: .sparkline,
            unit: "GB",
            scaleMode: .fixedRange(min: 0, max: 50),
            commandValue: {
                if let memory = await sampler.memoryUsagePercent() {
                    let formatter = ByteCountFormatter()
                    formatter.countStyle = .memory
                    let cachedText = formatter.string(fromByteCount: Int64(memory.cachedBytes))
                    let percent = (Double(memory.cachedBytes) / Double(memory.totalBytes)) * 100.0
                    let text = String(format: "%.0f%% (%@)", percent, cachedText)
                    return MetricSample(text: text, primary: percent, secondary: nil)
                }
                return MetricSample.text("n/a")
            },
            icon: Image(systemName: "tray.full")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "Network Inbound",
            category: "Performance",
            cadence: .fast,
            displayStyle: .sparkline,
            unit: "MB/s",
            scaleMode: nil,
            commandValue: {
                if let rates = await sampler.networkThroughput() {
                    let downMBps = rates.downBps / 1_048_576
                    return MetricSample(text: String(format: "%.1f MB/s", downMBps), primary: downMBps, secondary: nil)
                }
                return MetricSample.text("n/a")
            },
            icon: Image(systemName: "arrow.down")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "Network Outbound",
            category: "Performance",
            cadence: .fast,
            displayStyle: .sparkline,
            unit: "MB/s",
            scaleMode: nil,
            commandValue: {
                if let rates = await sampler.networkThroughput() {
                    let upMBps = rates.upBps / 1_048_576
                    return MetricSample(text: String(format: "%.1f MB/s", upMBps), primary: upMBps, secondary: nil)
                }
                return MetricSample.text("n/a")
            },
            icon: Image(systemName: "arrow.up")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "Disk Throughput",
            category: "Performance",
            cadence: .fast,
            displayStyle: .sparkline,
            unit: "MB/s",
            scaleMode: nil,
            commandValue: {
                if let disk = await sampler.diskThroughputMBps() {
                    return MetricSample(text: String(format: "%.1f MB/s", disk), primary: disk, secondary: nil)
                }
                return MetricSample.text("n/a")
            },
            icon: Image(systemName: "internaldrive")
        ))

        // Hardware entries temporarily disabled; keep this block commented out
        /*
        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "Thermal State",
            category: "Hidden",
            cadence: .medium,
            displayStyle: .text,
            unit: nil,
            scaleMode: nil,
            commandValue: {
                let state = thermalStateText()
                return MetricSample.text(state)
            },
            icon: Image(systemName: "thermometer")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "CPU Thermal Level",
            category: "Hidden",
            cadence: .medium,
            displayStyle: .text,
            unit: nil,
            scaleMode: nil,
            commandValue: {
                return MetricSample.text("Not available")
            },
            icon: Image(systemName: "gauge.with.dots.needle.50percent")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "Fan RPM",
            category: "Hidden",
            cadence: .medium,
            displayStyle: .text,
            unit: nil,
            scaleMode: nil,
            commandValue: {
                return MetricSample.text("Not available")
            },
            icon: Image(systemName: "fan")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "GPU Model",
            category: "Hidden",
            cadence: .slow,
            displayStyle: .text,
            unit: nil,
            scaleMode: nil,
            commandValue: {
                do {
                    let output = try await shell.run("system_profiler SPDisplaysDataType | awk -F: '/Chipset Model/ {print $2; exit}'", timeout: 5)
                    let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    return MetricSample.text(trimmed.isEmpty ? "n/a" : trimmed)
                } catch {
                    return MetricSample.text("Unavailable")
                }
            },
            icon: Image(systemName: "display")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "GPU Utilization",
            category: "Hidden",
            cadence: .medium,
            displayStyle: .text,
            unit: nil,
            scaleMode: nil,
            commandValue: {
                return MetricSample.text("Not available")
            },
            icon: Image(systemName: "gauge.high")
        ))


        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "Displays",
            category: "Hidden",
            cadence: .slow,
            displayStyle: .text,
            unit: nil,
            scaleMode: nil,
            commandValue: {
                do {
                    let output = try await shell.run("system_profiler SPDisplaysDataType | awk -F: '/Resolution/ {print $2; exit}'", timeout: 5)
                    let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    return MetricSample.text(trimmed.isEmpty ? "n/a" : trimmed)
                } catch {
                    return MetricSample.text("Unavailable")
                }
            },
            icon: Image(systemName: "display.2")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "Display Refresh / HDR",
            category: "Hidden",
            cadence: .slow,
            displayStyle: .text,
            unit: nil,
            scaleMode: nil,
            commandValue: {
                do {
                    let refresh = try await shell.run("system_profiler SPDisplaysDataType | awk -F: '/Refresh Rate/ {print $2; exit}'", timeout: 5)
                    let hdr = try await shell.run("system_profiler SPDisplaysDataType | awk -F: '/HDR/ {print $2; exit}'", timeout: 5)
                    let refreshTrimmed = refresh.trimmingCharacters(in: .whitespacesAndNewlines)
                    let hdrTrimmed = hdr.trimmingCharacters(in: .whitespacesAndNewlines)
                    let parts = [refreshTrimmed, hdrTrimmed].filter { !$0.isEmpty }
                    return MetricSample.text(parts.isEmpty ? "n/a" : parts.joined(separator: " • "))
                } catch {
                    return MetricSample.text("Unavailable")
                }
            },
            icon: Image(systemName: "rectangle.and.arrow.up.right.and.arrow.down.left")
        ))
        */

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "SMART Status",
            category: "Storage",
            cadence: .slow,
            displayStyle: .text,
            unit: nil,
            scaleMode: nil,
            commandValue: {
                do {
                    let output = try await shell.run("diskutil info / | awk -F: '/SMART/ {print $2; exit}'", timeout: 5)
                    let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    return MetricSample.text(trimmed.isEmpty ? "n/a" : trimmed)
                } catch {
                    return MetricSample.text("Unavailable")
                }
            },
            icon: Image(systemName: "stethoscope")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "Last Wake",
            category: "System",
            cadence: .medium,
            displayStyle: .text,
            unit: nil,
            scaleMode: nil,
            commandValue: {
                do {
                    let output = try await shell.run("pmset -g log | grep -E ' Wake ' | tail -1", timeout: 5)
                    let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    let prefix = String(trimmed.prefix(19))
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    if let date = formatter.date(from: prefix) {
                        let since = timeSince(date: date)
                        return MetricSample.text("Last wake: \(since) ago")
                    }
                    return MetricSample.text(trimmed.isEmpty ? "n/a" : trimmed)
                } catch {
                    return MetricSample.text("Unavailable")
                }
            },
            icon: Image(systemName: "moon.stars")
        ))

        statusEntries.append(StatusEntry(
            id: statusEntries.count,
            name: "Wake Reason",
            category: "System",
            cadence: .medium,
            displayStyle: .text,
            unit: nil,
            scaleMode: nil,
            commandValue: {
                do {
                    let output = try await shell.run("pmset -g log | grep -E ' Wake ' | tail -1 | awk -F'Wake reason: ' '{print $2}'", timeout: 5)
                    let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    return MetricSample.text(trimmed.isEmpty ? "n/a" : trimmed)
                } catch {
                    return MetricSample.text("Unavailable")
                }
            },
            icon: Image(systemName: "bolt.horizontal")
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
                    displayStyle: .text,
                    unit: nil,
                    scaleMode: nil,
                    commandValue: {
                        let info = getDiskSpaceInfo(for: volumeURL)
                        return MetricSample.text("\(info.usedCapacity) | \(info.availableCapacity) | \(info.totalCapacity)")
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
                let sample = await entry.commandValue()
                var didAppendHistory = false
                if entry.displayStyle == .sparkline, let primary = sample.primary {
                    didAppendHistory = appendHistoryIfNeeded(entryIndex: idx, primary: primary, entries: &updated)
                }
                if sample.text != entry.value ||
                    sample.primary != entry.primaryValue ||
                    sample.secondary != entry.secondaryValue ||
                    didAppendHistory {
                    updated[idx].value = sample.text
                    updated[idx].primaryValue = sample.primary
                    updated[idx].secondaryValue = sample.secondary
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
            let sample = await updated[idx].commandValue()
            updated[idx].value = sample.text
            updated[idx].primaryValue = sample.primary
            updated[idx].secondaryValue = sample.secondary
            if updated[idx].displayStyle == .sparkline, let primary = sample.primary {
                _ = appendHistoryIfNeeded(entryIndex: idx, primary: primary, entries: &updated)
            }
        }
        // Publish once after computing all values
        self.statusEntries = updated
    }

    private func appendHistoryIfNeeded(entryIndex: Int, primary: Double, entries: inout [StatusEntry]) -> Bool {
        let style = entries[entryIndex].displayStyle
        guard style == .sparkline else { return false }
        entries[entryIndex].history.append(primary)
        if entries[entryIndex].history.count > maxHistoryCount {
            entries[entryIndex].history.removeFirst(entries[entryIndex].history.count - maxHistoryCount)
        }
        return true
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
