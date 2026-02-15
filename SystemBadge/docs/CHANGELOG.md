# Changelog

All notable changes to SystemBadge are documented in this file.

---

## [Unreleased] - 2026-02-14

### UI Improvements (3 Major Fixes)

#### Added
- **Battery Graph**: SwiftUI shapes-based rendering with high-contrast text
  - Color-coded levels: green/orange/red
  - 8-point stroke outline for text visibility
  - Smooth animations and gradient fills
  - Reduced code by 35% (105 → 68 lines)

- **Network Filtering**: Smart interface detection
  - Active interfaces only (with assigned IPs)
  - 8 interface type icons (Wi-Fi, Ethernet, Thunderbolt, USB, Bluetooth, etc.)
  - Filters loopback (127.x) and link-local (169.254.x) addresses
  - Helper functions: `getIPAddress(for:)`, `isLoopbackOrLinkLocal(_:)`, `getIconForInterface(...)`

- **Storage Volumes**: Automatic volume discovery
  - Auto-detects all mounted volumes
  - 10-second refresh cycle for mount/unmount detection
  - Filters system volumes (Data, Preboot, Recovery, VM)
  - 4 volume type icons (internal, external, network, disk image)
  - Prevents CacheDelete errors by testing volume readability
  - Helper functions: `getIconForVolume(...)`, `checkVolumeChanges()`

#### Changed
- BatteryBarView: Complete redesign from character-based to shape-based
- StatusInfo: Added network filtering and storage monitoring
- PreferencesView: Removed manual backup volume configuration

#### Removed
- Manual backup volume path configuration
- Character-based battery bar rendering
- Display of inactive network interfaces

### Commit
```
Implement dynamic UI improvements: battery, network, and storage

- Redesign battery graph with shapes and high-contrast text
- Filter network interfaces to active connections only  
- Auto-detect storage volumes with 10-second refresh
- Add smart icon selection for interface/volume types
- Filter system volumes and prevent CacheDelete errors
```

---

## [Code Review Fixes] - 2025-09

### Critical Fixes (3)

#### Fixed
- **Uptime Calculation**: Corrected divisor from 84000 to 86400 (was 3.5% off)
- **Memory Management**: Added comprehensive comments for Core Foundation APIs
- **Backup Volume Path**: Made configurable via Preferences (later replaced with auto-discovery)

### Major Fixes (7)

#### Added
- **Public IP Fallback**: 3 services (api.ipify.org, icanhazip.com, ipecho.net) with validation
- **Async Shell Actor**: Replaced blocking `shellCmd()` with async `shell.run()`
- **Tab Icons**: Descriptive icons (network, desktopcomputer, bolt.fill, internaldrive)
- **Battery Helper**: Extracted duplicate code to `getBatteryPercentageHealth()`

#### Changed
- **Process Termination**: Added PID validation and structured concurrency
- **AppStorage**: Fixed unnecessary `.wrappedValue` access

#### Removed
- **Commented Code**: 45+ lines of debug code from AppDelegate

#### Deprecated
- `shellCmd()` - Use `shell.run()` with async/await instead

### Minor Fixes (2)

#### Added
- **Path Validation**: Check file exists before accessing in `getDiskSpaceInfo()`

#### Removed
- **Unused Variables**: Cleaned up PreferencesView

### Commit
```
Apply code review fixes: critical and major issues

Critical:
- Fix uptime calculation (84000 → 86400)
- Add memory management comments
- Make backup volume configurable

Major:
- Add public IP fallback (3 services)
- Deprecate synchronous shell wrapper
- Update tab icons
- Remove commented debug code
- Extract duplicate battery code
- Fix process termination race conditions
- Fix AppStorage usage

Minor:
- Add path validation
- Remove unused variables
```

---

## Summary of Changes

### Files Modified
- `StatusInfo.swift` - Network filtering, storage discovery, volume monitoring, uptime fix, IP fallback
- `BatteryBarView.swift` - Complete redesign with shapes
- `BatteryInfo.swift` - Memory comments, helper extraction
- `ContentView.swift` - Tab icons
- `AppDelegate.swift` - Removed comments
- `StatusEntryView.swift` - AppStorage fix
- `PreferencesView.swift` - Backup volume setting (added then removed)
- `DiskInfo.swift` - Path validation

### Statistics
- **Total Fixes**: 15 (12 code review + 3 UI)
- **Lines Changed**: ~610 total
- **Functions Added**: 9 helpers
- **Code Quality**: B+ → A-
- **Configuration**: Manual → Automatic

### New Helper Functions (9)
1. `getIPAddress(for:)` - Network IP retrieval
2. `isLoopbackOrLinkLocal(_:)` - IP validation
3. `getIconForInterface(localizedName:bsdName:)` - Network icons
4. `getIconForVolume(volumeURL:isInternal:isRemovable:isLocal:)` - Volume icons
5. `checkVolumeChanges()` - Volume monitoring
6. `getPowerSourceDescriptions()` - Battery info
7. `getBatteryHealth()` - Battery health
8. `getBatteryPercentageHealth()` - Battery percentage
9. `getPublicIPAddress()` - Public IP with fallbacks

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| Current | 2026-02-14 | UI improvements (battery, network, storage) |
| Previous | 2025-09 | Code review fixes (12 fixes) |

---

## Breaking Changes

### Configuration
- **Removed**: Manual backup volume path configuration
  - **Migration**: None needed - volumes auto-detected

### API
- **Deprecated**: `shellCmd(cmd:timeout:)`
  - **Migration**: Use `await shell.run(cmd, timeout: timeout)`

---

## Future Roadmap

### Planned
- Unit tests for calculations and formatting
- URLSession migration (replace curl)
- Error logging system
- Accessibility (VoiceOver support)
- Native APIs (replace shell commands)

### Proposed
- Volume health indicators (SMART status)
- IPv6 support
- Network traffic statistics
- Battery cycle count display
- Plugin architecture

---

*For detailed information, see [IMPLEMENTATION_GUIDE.md](./IMPLEMENTATION_GUIDE.md)*
