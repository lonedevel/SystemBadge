# SystemBadge

A lightweight macOS menu bar application that provides real-time system information and monitoring through an elegant popover interface.

![Platform](https://img.shields.io/badge/platform-macOS%2013.0+-blue)
![Swift](https://img.shields.io/badge/swift-6.0+-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-enabled-green)
![License](https://img.shields.io/badge/license-MIT-green)

## Overview

SystemBadge is a native macOS application built with SwiftUI and AppKit that displays comprehensive system information organized into categorized tabs. The app lives discreetly in your menu bar and provides instant access to critical system metrics including network information, hardware specifications, battery status, storage capacity, and more—all without requiring administrative privileges.

<img width="650" alt="SystemBadge Screenshot" src="https://via.placeholder.com/650x250?text=SystemBadge+Screenshot">

### Why SystemBadge?

- **Always Accessible**: Lives in your menu bar, one click away
- **Comprehensive**: 15+ system metrics across 5 categories
- **Lightweight**: Minimal resource usage with intelligent refresh cadence
- **Customizable**: Personalize colors, fonts, and displayed metrics
- **Native**: Built entirely with Swift, SwiftUI, and macOS APIs
- **Private**: All data collected locally, no telemetry or network tracking

## Features

### General Information
- **Current Date & Time**: Real-time date and time display
- **Hostname**: Both short and FQDN hostnames
- **User Information**: Current username and full name
- **System Uptime**: Live tracking of system uptime

### Network Monitoring
- **Network Interfaces**: Automatic detection and display of all network interfaces (Wi-Fi, Ethernet, etc.)
- **IP Addresses**: Local IP addresses for each interface
- **Public IP**: External/public IP address detection
- **FQDN Resolution**: Fully qualified domain name

### System Information
- **CPU Details**: Brand, model, and architecture information
- **CPU Cores/Threads**: Physical and logical core count
- **RAM**: Total system memory
- **Operating System**: macOS version and product name

### Power Management
- **Battery Health**: Overall battery health status
- **Battery Percentage**: Current charge level with visual bar graph
- **Custom Battery Visualization**: Unique text-based progress bar with centered percentage display

### Storage Information
- **Disk Capacity**: Total, used, and available capacity for root volume
- **External Volumes**: Support for monitoring additional volumes (e.g., backup drives)
- **Smart Formatting**: Human-readable file size formatting

## Architecture

### Core Components

#### 1. **StatusInfo.swift**
The heart of the application that manages all system metrics:
- **Async/Await Architecture**: Fully async command execution using modern Swift concurrency
- **Smart Refresh System**: Three-tiered refresh cadence system
  - Fast (1s): Real-time metrics like time and uptime
  - Medium (10s): Semi-dynamic data like battery and date
  - Slow (60s): Static information like CPU type and OS version
- **Shell Command Actor**: Thread-safe shell command execution with timeout protection
- **Timeout Handling**: Prevents hanging on slow/unresponsive commands (5s default timeout)

#### 2. **BatteryInfo.swift**
Dedicated battery monitoring using IOKit:
- **Battery Health Detection**: Reads native macOS battery health indicators
- **Accurate Percentage Calculation**: Calculates charge using current vs. max capacity
- **IOKit Integration**: Direct hardware API access for reliable data

#### 3. **DiskInfo.swift**
Storage space monitoring:
- **ResourceValues API**: Uses modern FileManager resource values
- **ByteCountFormatter**: Professional file size formatting
- **Error Handling**: Graceful degradation when volumes are unavailable

#### 4. **UI Components**

**ContentView.swift**
- Tab-based organization (General, Network, System, Power, Storage)
- Floating window level for always-on-top behavior
- Fixed window sizing for consistent UX
- Custom background color support

**StatusEntryView.swift**
- Reusable component for displaying metric entries
- Icon support with SF Symbols
- Customizable fonts and colors via AppStorage
- Special battery bar visualization for battery percentage

**BatteryBarView.swift**
- Custom text-based progress bar using block characters (█ and ░)
- Centered percentage label with inverse color overlay
- Configurable dimensions, fonts, and colors
- SwiftUI-native implementation

**AppDelegate.swift**
- Menu bar integration using NSStatusBar
- Popover presentation management
- Toggle show/hide functionality

**PreferencesView.swift**
- Settings UI with Appearance and Content tabs
- Font picker integration
- Color customization (metrics, labels, background)
- Feature toggles for CPU and public internet display

#### 5. **FontPicker.swift**
Custom SwiftUI component for system font selection using NSFontPanel.

## Technical Highlights

### Modern Swift Patterns
- **Swift Concurrency**: Extensive use of async/await, actors, and task groups
- **@MainActor**: Proper main thread isolation for UI updates
- **ObservableObject**: Reactive data flow with @Published properties
- **AppStorage**: Persistent user preferences

### Performance Optimizations
- **Cadence-based Refresh**: Avoids unnecessary computation by categorizing metrics
- **Lazy Evaluation**: Values computed on-demand
- **Timeout Protection**: Prevents resource exhaustion from hanging commands
- **Process Termination**: Graceful and forceful process cleanup (SIGTERM → SIGINT → SIGKILL)

### Shell Command Execution
The `Shell` actor provides safe, async shell command execution:
```swift
actor Shell {
    func run(_ command: String, timeout: TimeInterval = 5) async throws -> String
}
```
Features:
- Login shell (`/bin/zsh -lc`) for proper PATH and environment
- Separate stdout/stderr capture
- Race condition handling between completion and timeout
- Escalating termination strategy

## Installation

### Requirements
- macOS 13.0+ (for full async file handle support)
- Xcode 15.0+ (for Swift 6.0)

### Building from Source
1. Clone the repository
2. Open `SystemBadge.xcodeproj` in Xcode
3. Build and run (⌘R)

## Usage

1. Launch the app
2. A badge icon appears in your menu bar
3. Click the icon to open the system information popover
4. Navigate between tabs to view different categories
5. Access Settings from the macOS menu to customize appearance

### Keyboard Shortcuts
- **⌘,** - Open Preferences
- **Click menu bar icon** - Toggle popover

## Configuration

### AppStorage Keys
The app persists the following preferences:
- `showCpu`: Toggle CPU information display
- `showPublicInternet`: Toggle public IP lookup
- `metricColor`: Color for metric values
- `labelColor`: Color for metric labels
- `backgroundColor`: Popover background color

### Adding Custom Metrics
To add a new metric, edit `StatusInfo.buildEntries()`:

```swift
statusEntries.append(StatusEntry(
    id: statusEntries.count,
    name: "Your Metric Name",
    category: "General", // or Network, System, Power, Storage
    cadence: .medium,     // .fast, .medium, or .slow
    commandValue: {
        // Async closure that returns the metric value
        return "Your Value"
    },
    icon: Image(systemName: "icon.name")
))
```

## Project Structure

```
SystemBadge/
├── SystemBadgeApp.swift      # App entry point
├── AppDelegate.swift         # Menu bar integration
├── ContentView.swift         # Main UI
├── StatusInfo.swift          # Metric collection & refresh
├── BatteryInfo.swift         # Battery monitoring (IOKit)
├── DiskInfo.swift           # Storage information
├── StatusEntryView.swift    # Metric display component
├── BatteryBarView.swift     # Custom battery visualization
├── PreferencesView.swift    # Settings UI
└── FontPicker.swift         # Font selection component
```

## Known Limitations

1. **Hardcoded Backup Volume**: The backup disk path is hardcoded to `/Volumes/Backup-1`
2. **Public IP Lookup**: Depends on external service (ipecho.net)
3. **Shell Command Dependency**: Some metrics rely on external command-line tools
4. **macOS Only**: Platform-specific APIs (IOKit, NSStatusBar, NSFontPanel)
5. **No Error Reporting UI**: Failed commands return empty strings silently

## Future Enhancement Ideas

- [ ] Dynamic volume discovery for storage monitoring
- [ ] CPU/Memory/Network usage graphs
- [ ] Notification support for battery/storage thresholds
- [ ] Export system report to file
- [ ] Menu bar icon customization
- [ ] Widget support (macOS 14+)
- [ ] Historical data tracking
- [ ] Customizable metric visibility per-tab
- [ ] Localization support
- [ ] Dark mode optimization

## Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues for bugs and feature requests.

## License

MIT License - feel free to use this project for personal or commercial purposes.

## Credits

Created by Richard Michaud
- Original creation: January 29, 2022
- Battery/Disk features: September 21, 2025

## Technical Notes

### Font Requirements
The app uses "EnhancedDotDigital-7" font for metric display. Ensure this font is installed or modify the font name in:
- `StatusEntryView.swift` (line 48)
- `BatteryBarView.swift` (default parameter)

### Color Assets
The app expects these color assets in your asset catalog:
- `MetricColor`
- `LabelColor`
- `BackgroundColor`

### Icon Requirements
- Menu bar icon: `Icon` image asset
- Battery icon: `battery.75percent` image asset (or use SF Symbol alternative)
