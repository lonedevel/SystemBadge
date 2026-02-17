# SystemBadge Theme & Liquid Glass Guide

## Overview

SystemBadge now includes comprehensive theming support with automatic light/dark mode adaptation and modern Liquid Glass visual effects. This guide explains how to configure and customize these features.

## Features

### 🌓 Automatic Light/Dark Mode Support
The app automatically adapts to your macOS appearance settings, providing optimal contrast and readability in both modes.

### ✨ Liquid Glass Effect
A modern, dynamic glass material that:
- Blurs content behind the popover
- Reflects surrounding light and color
- Creates an immersive, fluid interface
- Adapts to light and dark mode automatically

### 🎨 Flexible Color Customization
Choose between:
- **System Colors**: Automatic adaptation to macOS appearance
- **Custom Colors**: Define your own color scheme
- Both options respect light/dark mode settings

## Configuration

### Accessing Preferences

1. Launch SystemBadge
2. Open **SystemBadge → Preferences** (⌘,) from the menu bar
3. Navigate through the three tabs:
   - **Appearance**: General theme and color settings
   - **Glass Effect**: Liquid Glass customization
   - **Content**: Display options for metrics

### Appearance Settings

#### Use System Colors
**Toggle:** `Use System Colors`
- **Enabled**: App automatically adapts colors to light/dark mode
- **Disabled**: Uses your custom color selections
- **Recommendation**: Keep enabled for best integration with macOS

#### Enable Liquid Glass
**Toggle:** `Enable Liquid Glass`
- **Enabled**: Applies dynamic glass effect to popover
- **Disabled**: Uses solid background color
- **Note**: When enabled, background color is automatically set to transparent

#### Custom Colors
When system colors are disabled, you can customize:
- **Metric Font**: Choose any installed system font
- **Metric Color**: Color for metric values (CPU, RAM, etc.)
- **Label Color**: Color for metric labels
- **Background Color**: Popover background (disabled when Liquid Glass is on)

### Glass Effect Settings

#### Corner Radius
**Slider:** 0-32 pixels
- Controls the roundness of the glass effect corners
- **Default**: 16 pixels
- **Lower values**: Sharper corners, more traditional
- **Higher values**: Rounder corners, more modern

#### Glass Tint
**Toggle:** `Enable Glass Tint`
- **Enabled**: Adds a subtle color tint to the glass effect
- **Disabled**: Pure glass effect without tint

When tint is enabled:
- **Glass Tint Color**: Choose any color
- **Note**: Colors are automatically made semi-transparent for best effect
- **Tip**: Subtle, desaturated colors work best

### Content Settings

Configure which metrics to display:
- **Show CPU**: Toggle CPU information visibility
- **Show Public Internet**: Toggle public IP address lookup

## Technical Implementation

### Architecture

#### GlassHostingController
Custom `NSHostingController` subclass that manages the Liquid Glass effect:
- Creates and manages `NSGlassEffectView`
- Responds to appearance changes
- Applies user preferences (corner radius, tint color)
- Positions glass view behind SwiftUI content

#### ContentView Theming
Dynamic background selection based on:
1. **Liquid Glass enabled**: Transparent background
2. **System colors**: Adaptive system background colors
3. **Custom**: User-selected background color

#### Theme Persistence
All settings are stored using `@AppStorage`:
```swift
@AppStorage("enableLiquidGlass") private var enableLiquidGlass = true
@AppStorage("useSystemColors") private var useSystemColors = true
@AppStorage("glassCornerRadius") private var glassCornerRadius = 16.0
@AppStorage("glassTintColor") private var glassTintColorData: Data?
```

### NSGlassEffectView Integration

The Liquid Glass effect uses Apple's native `NSGlassEffectView`:

```swift
let glass = NSGlassEffectView()
glass.cornerRadius = glassCornerRadius
glass.tintColor = optionalTintColor
```

#### Positioning
Glass view is inserted **below** SwiftUI content:
```swift
contentView.addSubview(glass, positioned: .below, relativeTo: nil)
```

#### Auto Layout
Glass view fills the entire popover:
```swift
NSLayoutConstraint.activate([
    glass.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
    glass.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
    glass.topAnchor.constraint(equalTo: contentView.topAnchor),
    glass.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
])
```

## Best Practices

### For Optimal Liquid Glass Effect

1. **Enable System Colors**: Let the app adapt colors automatically
2. **Subtle Tints**: If using tint, choose desaturated colors
3. **Appropriate Radius**: 12-20 pixels work well for most scenarios
4. **Transparent Content**: Let the glass effect show through

### For Custom Theming

1. **Test Both Modes**: Check your colors in light and dark mode
2. **Contrast Matters**: Ensure text remains readable
3. **Consistent Palette**: Use complementary colors for metrics and labels

### Performance Considerations

1. **Glass Effect**: Minimal performance impact on modern Macs
2. **System Colors**: Most efficient option
3. **Custom Colors**: No performance difference

## Troubleshooting

### Glass Effect Not Visible
- **Check**: Is "Enable Liquid Glass" toggled on?
- **Verify**: macOS 13.0+ is required for `NSGlassEffectView`
- **Try**: Restart the app after changing settings

### Colors Not Changing
- **Check**: Is "Use System Colors" enabled?
- **Verify**: Is "Enable Liquid Glass" enabled? (It overrides some color settings)
- **Try**: Toggle "Use System Colors" off to use custom colors

### Tint Color Not Applying
- **Check**: Is "Enable Glass Tint" toggled on?
- **Verify**: Is "Enable Liquid Glass" itself enabled?
- **Note**: Tint effects are subtle by design

## Advanced Customization

### Modifying ThemeManager

For developers, the `ThemeManager.swift` file provides centralized theme logic:

```swift
struct ThemeManager {
    let colorScheme: ColorScheme
    
    var metricColor: Color {
        // Dynamic color based on settings
    }
    
    var labelColor: Color {
        // Dynamic color based on settings
    }
}
```

### Extending Color Support

To add new theme colors:

1. Add `@AppStorage` property in relevant view
2. Add UI control in `PreferencesView`
3. Update `ThemeManager` if needed for dynamic behavior

### Custom Glass Effects

To further customize the glass effect:

1. Modify `GlassHostingController.setupGlassEffect()`
2. Adjust `NSGlassEffectView` properties
3. Consider adding new settings in `GlassEffectSettingsView`

## Examples

### Configuration Presets

#### Minimal Glass
```
Enable Liquid Glass: ✓
Use System Colors: ✓
Corner Radius: 20
Enable Glass Tint: ✗
```

#### Vibrant Blue Glass
```
Enable Liquid Glass: ✓
Use System Colors: ✓
Corner Radius: 16
Enable Glass Tint: ✓
Glass Tint Color: System Blue
```

#### Traditional Solid
```
Enable Liquid Glass: ✗
Use System Colors: ✗
Custom Colors: Set to your preference
```

## Keyboard Shortcuts

- **⌘,** - Open Preferences
- **⌘W** - Close Preferences window

## Related Technologies

- **NSGlassEffectView**: Apple's AppKit class for glass materials
- **@AppStorage**: SwiftUI property wrapper for UserDefaults
- **Environment(\.colorScheme)**: Detect light/dark mode
- **NSKeyedArchiver**: Persist NSColor objects

## Resources

- [Apple NSGlassEffectView Documentation](https://developer.apple.com/documentation/appkit/nsglasseffectview)
- [SwiftUI Color Scheme](https://developer.apple.com/documentation/swiftui/colorscheme)
- [AppStorage Documentation](https://developer.apple.com/documentation/swiftui/appstorage)

## Version History

- **v2.0** (2026): Added Liquid Glass support and comprehensive theming
- **v1.0** (2022): Initial release

---

**Need Help?** Open an issue on GitHub with your theme configuration and screenshots.
