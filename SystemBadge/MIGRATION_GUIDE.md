# Migration Guide: v1.0 → v2.0

## Overview

SystemBadge v2.0 introduces significant theming enhancements while maintaining full backward compatibility. Your existing settings are preserved, and new features are opt-in.

## What's Changed

### For Users

#### New Features Available
✨ **Liquid Glass Effect** - Modern blur and light reflection  
🌓 **Light/Dark Mode** - Automatic adaptation  
🎨 **Enhanced Theming** - More customization options  
⚙️ **New Settings Tab** - Dedicated Glass Effect controls  

#### What Stays the Same
✅ All existing metrics still work  
✅ Your custom colors are preserved  
✅ Content settings unchanged  
✅ Keyboard shortcuts identical  
✅ Menu bar icon and behavior  

### For Developers

#### Breaking Changes
**None!** All changes are additive.

#### New APIs Available
- `GlassHostingController` - Custom hosting with glass support
- `ThemeManager` - Centralized theme logic (optional)
- New `@AppStorage` keys for theme settings

## Migration Steps

### For Regular Users

**Good News**: No action needed! 

When you first launch v2.0:
1. Your existing custom colors are preserved
2. New features are enabled by default:
   - Liquid Glass: **Enabled**
   - System Colors: **Enabled**
   - Corner Radius: **16** (moderate roundness)
   - Tint: **Disabled**

**To restore v1.0 appearance**:
1. Open Preferences (⌘,)
2. Go to "Appearance" tab
3. Uncheck "Enable Liquid Glass"
4. Uncheck "Use System Colors"
5. Your custom colors will be restored

### For Developers

#### If you've customized the project

**Scenario 1**: You only changed colors in Asset Catalog
- **Impact**: None
- **Action**: Your colors work as before
- **New**: Users can override with system colors

**Scenario 2**: You modified `ContentView.swift`
- **Impact**: Minor - new properties added
- **Action**: Review background selection logic
- **New**: `dynamicBackground` computed property
- **Migration**: Merge your changes with new background logic

**Scenario 3**: You modified `AppDelegate.swift`
- **Impact**: Significant - new `GlassHostingController`
- **Action**: Review new hosting controller code
- **New**: Glass effect setup and observation
- **Migration**: Integrate glass controller or disable feature

**Scenario 4**: You modified `PreferencesView.swift`
- **Impact**: Significant - complete restructure
- **Action**: Review new tab structure
- **New**: Three tabs instead of two
- **Migration**: Integrate your custom settings into new structure

**Scenario 5**: You added custom metrics
- **Impact**: None
- **Action**: Continue using `StatusInfo.buildEntries()`
- **New**: Metrics automatically support theming

## Settings Migration

### UserDefaults Keys

#### Preserved (Unchanged)
```
showCpu: Bool
showPublicInternet: Bool
metricColor: Color (only used if system colors disabled)
labelColor: Color (only used if system colors disabled)
backgroundColor: Color (only used if glass disabled)
```

#### New (Auto-created)
```
useSystemColors: Bool (default: true)
enableLiquidGlass: Bool (default: true)
glassCornerRadius: Double (default: 16.0)
glassTintColor: Data? (default: nil)
```

### Migration Logic

```swift
// On first launch of v2.0, these values are created:

if UserDefaults.standard.object(forKey: "useSystemColors") == nil {
    // First launch of v2.0
    UserDefaults.standard.set(true, forKey: "useSystemColors")
    UserDefaults.standard.set(true, forKey: "enableLiquidGlass")
    UserDefaults.standard.set(16.0, forKey: "glassCornerRadius")
    // glassTintColor remains nil (no tint by default)
}

// Your existing color settings are never touched
// They're just not used unless you disable system colors
```

## Compatibility Matrix

| Setting | v1.0 | v2.0 Default | v2.0 Custom |
|---------|------|--------------|-------------|
| Custom Metric Color | ✓ | Used if system colors off | ✓ |
| Custom Label Color | ✓ | Used if system colors off | ✓ |
| Custom Background | ✓ | Not used (glass on) | ✓ if glass off |
| System Adaptation | ✗ | ✓ Automatic | ✓ Can disable |
| Glass Effect | ✗ | ✓ Enabled | ✓ Configurable |

## Visual Changes

### Default Appearance

#### v1.0 Default
```
┌─────────────────────┐
│  Solid Background   │
│  Static Colors      │
│  No Light Adaptation│
└─────────────────────┘
```

#### v2.0 Default
```
┌─────────────────────┐
│  Glass Background   │ ← Blurred, translucent
│  System Colors      │ ← Adapts to light/dark
│  Modern Design      │ ← Reflects light
└─────────────────────┘
```

#### v2.0 Traditional Mode
```
┌─────────────────────┐
│  Solid Background   │ ← Same as v1.0
│  Custom Colors      │ ← Your original colors
│  Classic Design     │ ← Familiar appearance
└─────────────────────┘
```

To get v1.0 appearance: Disable both "System Colors" and "Liquid Glass"

## Code Changes Summary

### Modified Files

#### `AppDelegate.swift`
```diff
- self.popover.contentViewController = NSHostingController(rootView: contentView)
+ self.glassHostingController = GlassHostingController(rootView: contentView)
+ self.popover.contentViewController = glassHostingController
+ // Added appearance change observation
```

#### `ContentView.swift`
```diff
+ @AppStorage("enableLiquidGlass") private var enableLiquidGlass = true
+ @AppStorage("useSystemColors") private var useSystemColors = true
+ @Environment(\.colorScheme) private var colorScheme
+
+ private var dynamicBackground: Color {
+     // New background selection logic
+ }
```

#### `StatusEntryView.swift`
```diff
- @AppStorage("metricColor") private var metricColor = Color("MetricColor")
+ @AppStorage("metricColor") private var customMetricColor = Color("MetricColor")
+ @AppStorage("useSystemColors") private var useSystemColors = true
+ 
+ private var metricColor: Color {
+     // Dynamic color selection
+ }
```

#### `PreferencesView.swift`
```diff
- .frame(width: 375, height: 300)
+ .frame(width: 450, height: 400)
+ // Added new GlassEffectSettingsView tab
+ // Enhanced appearance settings
```

### New Files

- `ThemeManager.swift` - Optional helper for theme logic
- `THEMING_GUIDE.md` - User documentation
- `THEME_IMPLEMENTATION.md` - Developer documentation
- `QUICKSTART_THEMING.md` - Quick start guide
- `ARCHITECTURE_DIAGRAM.md` - Visual architecture
- `IMPLEMENTATION_SUMMARY.md` - Complete overview
- `MIGRATION_GUIDE.md` - This file

## Testing Your Migration

### Checklist for Users

- [ ] Launch v2.0 and verify popover opens
- [ ] Check that your metrics still display correctly
- [ ] Try switching between light and dark mode
- [ ] Open Preferences and verify your old colors are present
- [ ] Toggle "Enable Liquid Glass" to see the effect
- [ ] Test with glass enabled and disabled
- [ ] Verify menu bar icon still works

### Checklist for Developers

- [ ] Review all modified files for conflicts
- [ ] Test with your custom colors
- [ ] Verify custom metrics still work
- [ ] Check any custom UI modifications
- [ ] Test appearance change handling
- [ ] Verify settings persistence
- [ ] Build and run without errors
- [ ] Test in both light and dark mode

## Rollback Instructions

If you need to revert to v1.0 behavior:

### Option 1: Keep v2.0, Use v1.0 Appearance
1. Open Preferences (⌘,)
2. Appearance tab:
   - ☐ Uncheck "Use System Colors"
   - ☐ Uncheck "Enable Liquid Glass"
3. Set your custom colors
4. Done! Now looks like v1.0

### Option 2: Actually Revert to v1.0
1. Close SystemBadge
2. Checkout v1.0 from git: `git checkout v1.0`
3. Rebuild in Xcode
4. Your settings in UserDefaults remain
   - v1.0 ignores new keys
   - Old settings still work

### Option 3: Remove New Settings
```bash
# Reset all v2.0 theme settings to defaults
defaults delete com.yourapp.SystemBadge useSystemColors
defaults delete com.yourapp.SystemBadge enableLiquidGlass
defaults delete com.yourapp.SystemBadge glassCornerRadius
defaults delete com.yourapp.SystemBadge glassTintColor

# Relaunch app - will recreate with defaults
```

## Troubleshooting

### "My custom colors don't show anymore"
**Cause**: System Colors is enabled (v2.0 default)  
**Fix**: Preferences → Appearance → Uncheck "Use System Colors"

### "Glass effect isn't visible"
**Cause**: May need to reopen popover, or macOS < 13.0  
**Fix**: Close and reopen popover, verify macOS version

### "App looks different in light/dark mode"
**Behavior**: This is intentional! v2.0 adapts to appearance  
**Fix**: To disable, uncheck "Use System Colors"

### "Preferences window is larger"
**Behavior**: Intentional to fit new Glass Effect tab  
**Impact**: None, more settings available now

### "Build errors after updating"
**Cause**: Potential merge conflicts in modified files  
**Fix**: Review modified files section above, resolve conflicts

## Best Practices

### For Users Upgrading

1. **Try the defaults first** - v2.0 defaults look great!
2. **Experiment with glass** - Adjust corner radius to taste
3. **Test both modes** - See how it looks in light and dark
4. **Read quick start** - See `QUICKSTART_THEMING.md` for presets
5. **Restore old look** - Easy to go back if preferred

### For Developers Upgrading

1. **Review changes** - Understand what's new before merging
2. **Test thoroughly** - Check light/dark mode behavior
3. **Update docs** - If you have custom documentation
4. **Consider adoption** - New features are well-architected
5. **Extend carefully** - Use existing patterns for consistency

## FAQ

**Q: Will my settings be lost?**  
A: No, all existing settings are preserved.

**Q: Do I have to use the new features?**  
A: No, you can disable glass and system colors to get v1.0 appearance.

**Q: Will this affect performance?**  
A: Minimal impact. Glass uses GPU, negligible on modern Macs.

**Q: Can I use some new features but not others?**  
A: Yes! All features are independently toggleable.

**Q: What if I have custom code?**  
A: Review the "Code Changes Summary" section above.

**Q: How do I get the classic look?**  
A: Disable "System Colors" and "Liquid Glass" in Preferences.

**Q: Can I contribute enhancements?**  
A: Yes! Follow the project's contribution guidelines.

**Q: Where's the best documentation to read?**  
A: Start with `QUICKSTART_THEMING.md` for practical use.

## Support

### If You Need Help

1. **Check documentation** - Extensive guides available
2. **Review this guide** - Covers common migration issues
3. **Search issues** - Someone may have had same question
4. **Open issue** - Include version, OS, and steps to reproduce
5. **Include config** - Your theme settings help diagnose

### Helpful Commands

```bash
# Check your current settings
defaults read com.yourapp.SystemBadge

# Reset specific setting
defaults delete com.yourapp.SystemBadge enableLiquidGlass

# Export your settings
defaults export com.yourapp.SystemBadge ~/systembadge-settings.plist

# Import settings
defaults import com.yourapp.SystemBadge ~/systembadge-settings.plist
```

## Resources

- `README.md` - Project overview
- `QUICKSTART_THEMING.md` - Fast setup guide
- `THEMING_GUIDE.md` - Comprehensive theming documentation
- `THEME_IMPLEMENTATION.md` - Technical implementation details
- `ARCHITECTURE_DIAGRAM.md` - Visual architecture reference

## Conclusion

SystemBadge v2.0 is a **non-breaking upgrade** that adds modern features while preserving everything you loved about v1.0. Your settings carry forward, and you can opt out of new features if preferred.

**Recommended approach**: Try the v2.0 defaults first. Most users love the modern glass look!

**Want classic v1.0?** Two toggles in Preferences restore the original appearance.

**Questions?** Check the documentation or open an issue.

**Welcome to v2.0! 🎉**

