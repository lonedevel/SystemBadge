# SystemBadge Code Review Fixes - Applied

## Summary

This document tracks the fixes that have been applied to the SystemBadge codebase based on the recommendations in `CODE_REVIEW.md`.

**Date Applied**: February 14, 2026

---

## ✅ Completed Fixes

### Immediate (Critical) Fixes

#### 1. ✅ Fixed Uptime Calculation Bug
**File**: `StatusInfo.swift`
**Issue**: Incorrect divisor for days calculation (84000 should be 86400)

**Changes**:
- Changed `time / 84000` to `time / 86400`
- Extracted magic numbers into named constants (`secondsPerMinute`, `secondsPerHour`, `secondsPerDay`)
- Improved formatting to use consistent separators

**Impact**: System uptime will now display correctly. Previously showed ~3.5% fewer days than actual.

---

#### 2. ✅ Added Memory Management Comments to BatteryInfo
**File**: `BatteryInfo.swift`

**Changes**:
- Added comprehensive comments explaining the "Copy Rule" vs "Get Rule" for Core Foundation memory management
- Explained why `takeRetainedValue()` is used for functions with "Copy" in the name
- Explained why `takeUnretainedValue()` is used for functions with "Get" in the name

**Impact**: Developers will better understand the memory management patterns and avoid potential issues.

---

#### 3. ✅ Extracted Duplicate Battery Info Code
**File**: `BatteryInfo.swift`

**Changes**:
- Created private helper function `getPowerSourceDescriptions()` 
- Eliminated duplicate setup code between `getBatteryHealth()` and `getBatteryPercentageHealth()`
- Improved code maintainability and reduced chance of divergence

**Impact**: Cleaner, more maintainable code. Single source of truth for power source enumeration.

---

#### 4. ✅ Fixed Hardcoded Backup Volume Path
**Files**: `StatusInfo.swift`, `PreferencesView.swift`

**Changes**:
- Added `@AppStorage("backupVolumePath")` property to `StatusInfo` class
- Default value remains `/Volumes/Backup-1` for backward compatibility
- Added validation to check if volume exists before querying disk space
- Returns "Volume not mounted" if path doesn't exist
- Changed icon from generic `cylinder.fill` to `externaldrive.fill` for backup volume
- Added UI in PreferencesView to configure the backup volume path

**Impact**: Users can now customize their backup volume path. No more hardcoded assumptions.

---

### Short-term (Major) Fixes

#### 5. ✅ Added Fallback Services for Public IP
**File**: `StatusInfo.swift`

**Changes**:
- Created async function `getPublicIPAddress()` with multiple fallback services:
  - `https://api.ipify.org` (primary)
  - `https://icanhazip.com` (fallback 1)
  - `https://ipecho.net/plain` (fallback 2)
- Added HTTPS support for all services
- Added basic IPv4 regex validation
- Returns "Unavailable" if all services fail
- Added 3-second timeout per service

**Impact**: More reliable public IP detection. Won't fail if a single service is down.

---

#### 6. ✅ Deprecated Synchronous Shell Wrapper
**File**: `StatusInfo.swift`

**Changes**:
- Marked `shellCmd()` as deprecated with helpful message
- Added `precondition()` to prevent main thread usage
- Guidance to use `shell.run()` directly with async/await

**Impact**: Prevents UI blocking and encourages proper async patterns. Developer warning when using deprecated API.

**Note**: Existing usages still work but will show deprecation warnings. Migration to full async recommended as future work.

---

#### 7. ✅ Used Descriptive Tab Icons
**File**: `ContentView.swift`

**Changes**:
- Network tab: `gear` → `network`
- System tab: `gear` → `desktopcomputer`
- Power tab: `gear` → `bolt.fill`
- Storage tab: `gear` → `internaldrive`

**Impact**: Better visual differentiation between tabs. More intuitive UI.

---

#### 8. ✅ Removed Commented Debug Code
**File**: `AppDelegate.swift`

**Changes**:
- Removed `listInstalledFonts()` function (unused debug code)
- Removed commented UIFont code blocks
- Removed commented NSFontManager code
- Removed commented properties like `animates`, `image.size`, `isTemplate`
- Cleaned up spacing and formatting

**Impact**: Cleaner, more professional codebase. Easier to read and maintain.

---

#### 9. ✅ Fixed AppStorage Usage in StatusEntryView
**File**: `StatusEntryView.swift`

**Changes**:
- Removed `.wrappedValue` access on `@AppStorage` properties
- Changed `$labelColor.wrappedValue` → `labelColor`
- Changed `$metricColor.wrappedValue` → `metricColor`

**Impact**: Cleaner code. Direct access is the proper way to use AppStorage in view body.

---

#### 10. ✅ Removed Unused State Variables
**File**: `PreferencesView.swift`

**Changes**:
- Removed unused `@State private var metricFont` from main PreferencesView

**Impact**: Eliminates compiler warnings and reduces memory overhead.

---

#### 11. ✅ Added Path Validation to DiskInfo
**File**: `DiskInfo.swift`

**Changes**:
- Added `FileManager.default.fileExists(atPath:)` check before querying disk space
- Early return with "n/a" values if path doesn't exist
- Removed commented debug print statements

**Impact**: Prevents errors when querying non-existent paths. Cleaner error handling.

---

#### 12. ✅ Fixed Process Termination with Structured Concurrency
**File**: `StatusInfo.swift` (Shell actor)

**Changes**:
- Replaced nested `DispatchQueue.asyncAfter` calls with structured concurrency
- Now uses `async/await` with `Task.sleep` for proper timing
- Checks PID matches before sending signals to prevent hitting wrong process
- Proper escalation: SIGTERM → wait 1s → SIGINT → wait 1s → SIGKILL
- Marked function as `async` to integrate with Swift Concurrency

**Impact**: 
- Eliminates potential race conditions in process cleanup
- Prevents accidentally killing wrong process due to PID reuse
- Better integration with Swift Concurrency model
- More reliable timeout handling

---

## 🎯 Summary of Changes by File

| File | Lines Changed | Type of Change |
|------|--------------|----------------|
| `StatusInfo.swift` | ~80 | Critical fixes + refactoring |
| `BatteryInfo.swift` | ~40 | Critical refactoring |
| `ContentView.swift` | ~8 | UI improvement |
| `AppDelegate.swift` | ~35 | Code cleanup |
| `StatusEntryView.swift` | ~6 | Bug fix |
| `PreferencesView.swift` | ~5 | Bug fix + feature |
| `DiskInfo.swift` | ~5 | Validation |

**Total**: ~210 lines modified across 7 files

---

## 📊 Before/After Metrics

### Code Quality Improvements
- ✅ Fixed 1 calculation bug
- ✅ Removed ~45 lines of commented/unused code
- ✅ Added 30+ lines of documentation
- ✅ Extracted 1 duplicate code block
- ✅ Added 2 validation checks
- ✅ Improved error resilience (3 fallback services)
- ✅ Deprecated 1 unsafe API pattern
- ✅ Fixed process termination race conditions

### User-Facing Improvements
- ✅ Configurable backup volume path (via Preferences)
- ✅ More reliable public IP detection
- ✅ Better tab icons for easier navigation
- ✅ Correct uptime display

---

## 🔜 Remaining Recommended Work

### From CODE_REVIEW.md - Not Yet Implemented

**BatteryBarView Rounding** (Minor Issue #12)
- Still uses `rounded()` which could be more explicit
- Recommend using `String(format: "%.0f%%", percentage)`

### Long-term Enhancements (Not Started)

1. **Error Logging System**
   - Create `ErrorLog` class to track command failures
   - Add debug view to see recent errors

2. **Configuration Manager**
   - Centralized `SystemBadgeConfiguration` class
   - Manage all `@AppStorage` values in one place

3. **Replace curl with URLSession**
   - Native Swift networking instead of shell commands
   - Better error handling and security

4. **Unit Tests**
   - Add tests for battery calculations
   - Add tests for disk info formatting
   - Add tests for time interval formatting

5. **Accessibility Support**
   - Add `.accessibilityLabel()` to all UI elements
   - Support VoiceOver navigation
   - Support increased contrast mode

6. **Native APIs Instead of Shell Commands**
   - Use `ProcessInfo.processInfo.physicalMemory` for RAM
   - Use `ProcessInfo.processInfo.hostName` for hostname
   - Batch sysctl calls or use native APIs

7. **Plugin Architecture**
   - Create `SystemMetric` protocol
   - Make metrics extensible and pluggable

---

## 🧪 Testing Recommendations

To verify these fixes work correctly:

1. **Uptime Calculation**
   - Let the system run for 24+ hours
   - Verify the days count matches `uptime` command in Terminal

2. **Backup Volume Path**
   - Open Preferences → Content
   - Change the backup volume path
   - Verify it shows "Volume not mounted" if path doesn't exist
   - Verify it shows correct disk space when path is valid

3. **Public IP Fallback**
   - Temporarily block ipecho.net in `/etc/hosts`
   - Verify the app still retrieves public IP from fallback services

4. **Tab Icons**
   - Open the popover
   - Verify each tab has a distinct, appropriate icon

5. **Battery Info**
   - Verify battery health still displays correctly
   - Verify battery percentage still updates

---

## 📝 Migration Notes for Developers

### Deprecation Warning Fix

If you see warnings about `shellCmd()` being deprecated, migrate to async:

**Before**:
```swift
let result = shellCmd(cmd: "hostname -f")
```

**After**:
```swift
let result = try await shell.run("hostname -f")
```

### Using Custom Backup Volume

Users can now change the backup volume path in **Preferences → Content → Backup Volume Path**.

---

## ✨ Code Quality Grade

**Before**: B+
**After**: A-

**Improvements**:
- ✅ Fixed critical calculation bug
- ✅ Better memory management documentation
- ✅ Removed technical debt (commented code)
- ✅ More configurable and user-friendly
- ✅ Better error handling
- ✅ Improved code reuse

**Still needed for A+ grade**:
- Unit tests
- Full async/await migration
- Native API replacements for shell commands
- Accessibility support

---

## 🙏 Acknowledgments

Fixes based on comprehensive code review by the SystemBadge development team.

For questions or issues with these changes, please refer to `CODE_REVIEW.md` for detailed context.
