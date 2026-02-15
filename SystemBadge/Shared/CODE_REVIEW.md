# SystemBadge Code Review

## Executive Summary

SystemBadge is a well-structured macOS menu bar application with modern Swift patterns. The codebase demonstrates good use of Swift concurrency, SwiftUI, and platform APIs. However, there are several areas for improvement in error handling, configuration flexibility, and code maintainability.

**Overall Grade: B+**

---

## Critical Issues 🔴

### 1. **BatteryInfo.swift** - Potential Memory Leaks

**Issue**: Using `takeRetainedValue()` and `takeUnretainedValue()` inconsistently
```swift
guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
    return nil
}
// ...
guard let description = IOPSGetPowerSourceDescription(blob, ps)?.takeUnretainedValue() as? [String: Any] else {
```

**Problem**: 
- `IOPSCopyPowerSourcesInfo()` follows the Create Rule (Copy in name) - ownership is transferred, so `takeRetainedValue()` is correct
- `IOPSGetPowerSourceDescription()` follows the Get Rule - doesn't transfer ownership, so `takeUnretainedValue()` is correct
- However, mixing these in the same function can be confusing

**Recommendation**: Add comments explaining the memory management
```swift
// Copy rule - we own the blob, transfer ownership to Swift
guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
    return nil
}

// Get rule - we don't own this, just borrow it
guard let description = IOPSGetPowerSourceDescription(blob, ps)?.takeUnretainedValue() as? [String: Any] else {
```

### 2. **StatusInfo.swift** - Synchronous Wrapper with Deadlock Risk

**Issue**: The `shellCmd` function uses a semaphore to block waiting for async work
```swift
func shellCmd(cmd: String, timeout: TimeInterval = 5) -> String {
    let sem = DispatchSemaphore(value: 0)
    var result = ""
    Task {
        do { result = try await shell.run(cmd, timeout: timeout) } catch { result = "" }
        sem.signal()
    }
    sem.wait()
    return result
}
```

**Problem**:
- If called from the main thread, this could block the UI
- Defeats the purpose of async/await
- Can cause deadlocks in certain scenarios

**Recommendation**: Mark as deprecated and migrate all callers to async
```swift
@available(*, deprecated, message: "Use shell.run() directly with async/await")
func shellCmd(cmd: String, timeout: TimeInterval = 5) -> String {
    // Keep for backward compatibility but discourage use
    precondition(!Thread.isMainThread, "shellCmd must not be called from main thread")
    // ... existing implementation
}
```

Better yet, convert all usages to async in `buildEntries()`.

---

## Major Issues 🟡

### 3. **StatusInfo.swift** - Hardcoded Backup Volume Path

**Issue**: Line 408
```swift
let info = getDiskSpaceInfo(for: URL(fileURLWithPath: "/Volumes/Backup-1"))
```

**Problem**: Assumes specific volume name exists

**Recommendation**: Make it configurable or auto-discover mounted volumes
```swift
// In StatusInfo class
@AppStorage("backupVolumePath") private var backupVolumePath = "/Volumes/Backup-1"

// Or auto-discover volumes
func getMountedVolumes() -> [URL] {
    let fileManager = FileManager.default
    let volumeURLs = fileManager.mountedVolumeURLs(
        includingResourceValuesForKeys: [.volumeNameKey, .volumeIsRemovableKey],
        options: .skipHiddenVolumes
    ) ?? []
    return volumeURLs.filter { $0.path != "/" } // Exclude root
}
```

### 4. **StatusInfo.swift** - External Service Dependency Without Fallback

**Issue**: Line 303
```swift
let cmd = "curl --silent ipecho.net/plain ; echo"
```

**Problem**: 
- Single point of failure (ipecho.net could be down)
- No HTTPS
- No error handling if network is unavailable

**Recommendation**: Add fallback services and use HTTPS
```swift
commandValue: {
    let services = [
        "https://api.ipify.org",
        "https://icanhazip.com",
        "https://ipecho.net/plain"
    ]
    
    for service in services {
        let cmd = "curl --silent --max-time 3 '\(service)'"
        let result = shellCmd(cmd: cmd, timeout: 5).trimmingCharacters(in: .whitespacesAndNewlines)
        if !result.isEmpty && result.range(of: #"^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$"#, options: .regularExpression) != nil {
            return result
        }
    }
    return "Unavailable"
},
```

### 5. **StatusInfo.swift** - Process Termination Timing Issues

**Issue**: Lines 37-46
```swift
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
```

**Problem**: 
- Nested DispatchQueue calls don't guarantee cleanup
- No cancellation when process terminates
- Could send SIGKILL to a different process (PID reuse)

**Recommendation**: Use structured concurrency
```swift
func terminateProcess() async {
    guard process.isRunning else { return }
    let pid = process.processIdentifier
    
    process.terminate()
    try? await Task.sleep(nanoseconds: 1_000_000_000)
    
    guard process.isRunning, process.processIdentifier == pid else { return }
    process.interrupt()
    try? await Task.sleep(nanoseconds: 1_000_000_000)
    
    guard process.isRunning, process.processIdentifier == pid else { return }
    #if canImport(Darwin)
    Darwin.kill(pid, SIGKILL)
    #endif
}
```

### 6. **AppDelegate.swift** - Commented-Out Debug Code

**Issue**: Lines 17-44 contain large blocks of commented code

**Problem**: Clutters the codebase and suggests incomplete cleanup

**Recommendation**: Remove commented debug code or extract to a separate debug utility file

### 7. **ContentView.swift** - Duplicate Tab Icons

**Issue**: Multiple tabs use the same "gear" icon
```swift
.tabItem{ Label("Network", systemImage: "gear") }
.tabItem{ Label("System", systemImage: "gear") }
.tabItem{ Label("Power", systemImage: "gear") }
.tabItem{ Label("Storage", systemImage: "gear") }
```

**Recommendation**: Use descriptive icons
```swift
.tabItem{ Label("Network", systemImage: "network") }
.tabItem{ Label("System", systemImage: "desktopcomputer") }
.tabItem{ Label("Power", systemImage: "bolt.fill") }
.tabItem{ Label("Storage", systemImage: "internaldrive") }
```

---

## Minor Issues 🟢

### 8. **BatteryInfo.swift** - Duplicate Code

Both `getBatteryHealth()` and `getBatteryPercentageHealth()` have identical setup code.

**Recommendation**: Extract common logic
```swift
private func getPowerSourceDescriptions() -> [[String: Any]]? {
    guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
          let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else {
        return nil
    }
    
    return list.compactMap { ps in
        IOPSGetPowerSourceDescription(blob, ps)?.takeUnretainedValue() as? [String: Any]
    }
}

func getBatteryHealth() -> String? {
    guard let descriptions = getPowerSourceDescriptions() else { return nil }
    
    for description in descriptions {
        if let health = description[kIOPSBatteryHealthKey as String] as? String {
            return health
        }
    }
    return nil
}
```

### 9. **StatusInfo.swift** - Magic Numbers

**Issue**: Line 364 and elsewhere - `stringFromTimeInterval()` calculation
```swift
let days = (time / 84000)  // Should be 86400 (seconds in a day)
```

**Problem**: Incorrect calculation AND magic number

**Recommendation**:
```swift
extension TimeInterval {
    func stringFromTimeInterval() -> String {
        let time = Int(self)
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
```

### 10. **StatusEntryView.swift** - Force Unwrapping AppStorage

**Issue**: Lines 26, 31, 37, 42
```swift
.foregroundColor($labelColor.wrappedValue)
```

**Problem**: While unlikely to fail, direct access is cleaner

**Recommendation**:
```swift
.foregroundColor(labelColor)  // AppStorage unwraps automatically in body
```

### 11. **PreferencesView.swift** - Unused State Variable

**Issue**: Line 11
```swift
@State private var metricFont: NSFont = NSFont.systemFont(ofSize: 12)
```

**Problem**: Declared but never used in the view body

**Recommendation**: Remove or implement font persistence

### 12. **BatteryBarView.swift** - Rounding Inconsistency

**Issue**: Line 31
```swift
let percentStr = String(format: "%g%%", percentage.rounded())
```

**Problem**: Rounds to nearest integer, but StatusInfo can provide decimal percentages

**Recommendation**: Be explicit about rounding strategy
```swift
let percentStr = String(format: "%.0f%%", percentage)  // Always show as integer
```

---

## Code Quality Observations

### Strengths ✅

1. **Modern Swift Concurrency**: Excellent use of async/await and actors
2. **Separation of Concerns**: Clear separation between UI, data, and system APIs
3. **Type Safety**: Good use of enums for refresh cadence
4. **Reactive UI**: Proper use of @Published and ObservableObject
5. **SwiftUI Best Practices**: Good component composition

### Areas for Improvement 📈

1. **Error Handling**: Silent failures make debugging difficult
2. **Testing**: No unit tests or preview configurations
3. **Documentation**: Minimal inline comments
4. **Configuration**: Many hardcoded values should be configurable
5. **Accessibility**: No accessibility labels or VoiceOver support

---

## Architectural Recommendations

### 1. Introduce a Configuration System

Create a centralized configuration manager:
```swift
@MainActor
class SystemBadgeConfiguration: ObservableObject {
    @AppStorage("refreshFast") var refreshFast = 1
    @AppStorage("refreshMedium") var refreshMedium = 10
    @AppStorage("refreshSlow") var refreshSlow = 60
    @AppStorage("commandTimeout") var commandTimeout = 5.0
    @AppStorage("additionalVolumes") var additionalVolumes: [String] = []
    @AppStorage("publicIPServices") var publicIPServices: [String] = [
        "https://api.ipify.org",
        "https://icanhazip.com"
    ]
}
```

### 2. Add Error Reporting

Create a simple error tracking system:
```swift
@MainActor
class ErrorLog: ObservableObject {
    @Published var errors: [ErrorEntry] = []
    
    struct ErrorEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let command: String
        let error: String
    }
    
    func log(command: String, error: Error) {
        errors.append(ErrorEntry(
            timestamp: Date(),
            command: command,
            error: error.localizedDescription
        ))
        // Keep only last 100 errors
        if errors.count > 100 {
            errors.removeFirst()
        }
    }
}
```

### 3. Plugin Architecture for Metrics

Make metrics extensible:
```swift
protocol SystemMetric {
    var id: String { get }
    var name: String { get }
    var category: String { get }
    var icon: Image { get }
    var cadence: RefreshCadence { get }
    func getValue() async -> String
}

struct CPUMetric: SystemMetric {
    let id = "cpu.type"
    let name = "CPU Type"
    let category = "System"
    let icon = Image(systemName: "cpu")
    let cadence: RefreshCadence = .slow
    
    func getValue() async -> String {
        // Implementation
    }
}
```

### 4. Localization Support

Prepare for multiple languages:
```swift
extension String {
    var localized: String {
        NSLocalizedString(self, comment: "")
    }
}

// Usage
name: "CPU Type".localized
```

---

## Testing Recommendations

### Unit Tests Needed

1. **BatteryInfo**
   - Test percentage calculation with edge cases (0%, 100%, >100%)
   - Test missing battery scenarios
   - Test invalid capacity values

2. **DiskInfo**
   - Test with missing volumes
   - Test formatting edge cases
   - Test permission issues

3. **StatusInfo**
   - Test refresh cadence logic
   - Test command timeout behavior
   - Test concurrent refresh handling

### UI Tests Needed

1. Popover show/hide
2. Tab navigation
3. Settings persistence
4. Color customization

---

## Performance Considerations

### Current Performance Profile
- **Good**: Cadence-based refresh prevents over-polling
- **Good**: Async operations don't block UI
- **Concern**: Shell commands spawn new processes (overhead)
- **Concern**: No caching of slow-changing values across app launches

### Optimization Suggestions

1. **Cache Static Values**
```swift
@AppStorage("cachedCPUType") private var cachedCPUType: String?
@AppStorage("cachedRAM") private var cachedRAM: String?

// Only refresh on first launch or manually
if cachedCPUType == nil {
    cachedCPUType = await getCPUType()
}
```

2. **Batch Shell Commands**
Instead of running `sysctl` multiple times, run once and parse:
```swift
let sysctlOutput = await shell.run("sysctl -a")
// Parse all needed values from one output
```

3. **Use Native APIs Where Possible**
Replace shell commands with native Swift/Foundation APIs:
```swift
// Instead of: sysctl -n hw.memsize
let memsize = ProcessInfo.processInfo.physicalMemory

// Instead of: hostname
let hostname = ProcessInfo.processInfo.hostName
```

---

## Security Considerations

### Current Issues

1. **Shell Injection Risk**: Command strings are not sanitized
   - If interface names ever contain special characters, could be exploited
   
2. **No Input Validation**: User preferences aren't validated

3. **External Network Calls**: curl to third-party services without certificate validation

### Recommendations

1. **Sanitize Shell Arguments**
```swift
func escapeShellArgument(_ arg: String) -> String {
    return "'\(arg.replacingOccurrences(of: "'", with: "'\\''"))'"
}
```

2. **Use URLSession Instead of curl**
```swift
func getPublicIP() async throws -> String {
    let url = URL(string: "https://api.ipify.org")!
    let (data, _) = try await URLSession.shared.data(from: url)
    return String(data: data, encoding: .utf8) ?? ""
}
```

3. **Validate Paths**
```swift
func getDiskSpaceInfo(for path: URL) -> (String, String, String) {
    guard path.hasDirectoryPath,
          FileManager.default.fileExists(atPath: path.path) else {
        return ("n/a", "n/a", "n/a")
    }
    // ... rest of implementation
}
```

---

## Accessibility Gaps

The app currently has no accessibility support. Recommendations:

1. **Add Accessibility Labels**
```swift
.accessibilityLabel("\(name): \(value)")
.accessibilityValue(value)
```

2. **Support VoiceOver**
```swift
.accessibilityElement(children: .combine)
```

3. **Keyboard Navigation**
```swift
.focusable()
.onKeyPress(.space) { /* toggle popover */ }
```

4. **Increased Contrast Mode Support**
```swift
@Environment(\.accessibilityDifferentiateWithoutColor) var noColor
```

---

## Summary of Recommended Fixes

### Immediate (Critical)
1. ✅ Fix uptime calculation (84000 → 86400)
2. ✅ Add memory management comments to BatteryInfo
3. ✅ Fix hardcoded backup volume path

### Short-term (Major)
4. ✅ Add fallback for public IP service
5. ✅ Replace sync shell wrapper with async
6. ✅ Use descriptive tab icons
7. ✅ Remove commented debug code
8. ✅ Extract duplicate battery info code

### Long-term (Enhancement)
9. ✅ Add error logging system
10. ✅ Implement configuration manager
11. ✅ Add unit tests
12. ✅ Replace curl with URLSession
13. ✅ Add accessibility support
14. ✅ Implement plugin architecture for metrics

---

## Conclusion

SystemBadge is a solid foundation with good architecture and modern Swift patterns. The main areas for improvement are error handling, flexibility, and user configurability. With the recommended changes, this could be a robust, maintainable, and user-friendly system utility.

**Priority**: Focus first on fixing the uptime calculation bug and making the backup volume path configurable. Then work on replacing synchronous shell calls with proper async implementations.
