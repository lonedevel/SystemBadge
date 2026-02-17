# 🔨 Build & Test Checklist

Use this checklist to verify that the theme implementation works correctly.

## 📋 Pre-Build Checklist

### Files Added
- [ ] `ThemeManager.swift` exists in project
- [ ] All documentation files added to project (optional, for reference)

### Files Modified
- [ ] `AppDelegate.swift` - Has `GlassHostingController` class
- [ ] `ContentView.swift` - Has `dynamicBackground` property
- [ ] `StatusEntryView.swift` - Has dynamic color properties
- [ ] `PreferencesView.swift` - Has three tabs (Appearance, Glass Effect, Content)
- [ ] `README.md` - Updated with v2.0 features

### Xcode Project Setup
- [ ] All modified .swift files are in the Xcode project
- [ ] Files compile without errors
- [ ] No missing imports
- [ ] Minimum deployment target is macOS 13.0 or higher

## 🔨 Build Checklist

### Initial Build
- [ ] Clean build folder (⌘⇧K)
- [ ] Build project (⌘B)
- [ ] No compilation errors
- [ ] No warnings (or only expected warnings)

### Build Verification
- [ ] App bundle created successfully
- [ ] No missing resources
- [ ] Icon assets present
- [ ] Info.plist correct

## 🧪 Testing Checklist

### First Launch
- [ ] App launches successfully
- [ ] Menu bar icon appears
- [ ] Click icon opens popover
- [ ] Popover shows glass effect (should see subtle blur)
- [ ] All tabs visible (General, Network, System, Power, Storage)
- [ ] Metrics display correctly

### Light Mode Testing
- [ ] Switch macOS to Light Mode (System Settings → Appearance → Light)
- [ ] Open SystemBadge popover
- [ ] Glass effect visible with light appearance
- [ ] Text is readable (dark on light)
- [ ] All colors appropriate for light mode
- [ ] No visual glitches

### Dark Mode Testing
- [ ] Switch macOS to Dark Mode (System Settings → Appearance → Dark)
- [ ] Open SystemBadge popover
- [ ] Glass effect visible with dark appearance
- [ ] Text is readable (light on dark)
- [ ] All colors appropriate for dark mode
- [ ] No visual glitches

### Automatic Switching
- [ ] Open SystemBadge popover
- [ ] Switch macOS appearance (Light ↔ Dark)
- [ ] Close and reopen popover
- [ ] Colors update appropriately
- [ ] Glass effect adapts

### Preferences Testing

#### Opening Preferences
- [ ] Press ⌘, to open Preferences
- [ ] Preferences window opens
- [ ] Window size is ~450x400
- [ ] Three tabs visible

#### Appearance Tab
- [ ] "Use System Colors" toggle works
- [ ] "Enable Liquid Glass" toggle works
- [ ] Font picker displays
- [ ] Color pickers display
- [ ] Color pickers disabled when appropriate
- [ ] Help text shows current mode (Light/Dark)

#### Glass Effect Tab
- [ ] "Enable Liquid Glass Effect" toggle works
- [ ] Corner radius slider (0-32) works
- [ ] Current value displays next to slider
- [ ] "Enable Glass Tint" toggle works
- [ ] Tint color picker appears when enabled
- [ ] Informational sections display correctly

#### Content Tab
- [ ] "Show CPU" toggle works
- [ ] "Show Public Internet" toggle works
- [ ] Storage info text displays

### Settings Persistence
- [ ] Change settings in Preferences
- [ ] Close Preferences
- [ ] Quit app (⌘Q)
- [ ] Relaunch app
- [ ] Open Preferences
- [ ] Settings are preserved

### Glass Effect Testing

#### Enable/Disable
- [ ] Open Preferences → Glass Effect
- [ ] Check "Enable Liquid Glass Effect"
- [ ] Close and reopen popover
- [ ] Glass effect visible
- [ ] Uncheck "Enable Liquid Glass Effect"
- [ ] Close and reopen popover
- [ ] Solid background (no glass)

#### Corner Radius
- [ ] Enable glass effect
- [ ] Set corner radius to 0
- [ ] Close and reopen popover
- [ ] Sharp corners (square)
- [ ] Set corner radius to 32
- [ ] Close and reopen popover
- [ ] Very rounded corners
- [ ] Set corner radius to 16 (default)
- [ ] Close and reopen popover
- [ ] Moderate rounding

#### Tint Color
- [ ] Enable glass effect
- [ ] Enable glass tint
- [ ] Choose blue color
- [ ] Close and reopen popover
- [ ] Subtle blue tint visible
- [ ] Disable glass tint
- [ ] Close and reopen popover
- [ ] No tint (pure glass)

### System Colors Testing

#### With System Colors Enabled
- [ ] Enable "Use System Colors"
- [ ] Enable "Liquid Glass"
- [ ] Open popover in light mode
- [ ] Metric values readable
- [ ] Labels readable
- [ ] Switch to dark mode
- [ ] Colors inverted appropriately

#### With System Colors Disabled
- [ ] Disable "Use System Colors"
- [ ] Set custom metric color (e.g., green)
- [ ] Set custom label color (e.g., blue)
- [ ] Open popover
- [ ] Custom colors applied
- [ ] Switch light/dark mode
- [ ] Custom colors remain (don't adapt)

### Background Color Testing
- [ ] Disable "Enable Liquid Glass"
- [ ] Select custom background color (e.g., red)
- [ ] Open popover
- [ ] Background is custom color
- [ ] Enable "Enable Liquid Glass"
- [ ] Open popover
- [ ] Background transparent (glass shows)

### Metric Display Testing
- [ ] All metrics display in General tab
- [ ] All metrics display in Network tab
- [ ] All metrics display in System tab
- [ ] All metrics display in Power tab
- [ ] All metrics display in Storage tab
- [ ] Battery bar displays correctly
- [ ] No missing values (or shows graceful errors)

### Edge Cases

#### Rapid Switching
- [ ] Switch appearance multiple times quickly
- [ ] No crashes
- [ ] Colors eventually update correctly

#### Multiple Opens
- [ ] Open and close popover 10+ times
- [ ] No memory leaks (check Activity Monitor)
- [ ] Glass effect remains consistent

#### Window Management
- [ ] Open Preferences
- [ ] Open popover (should still work)
- [ ] Close Preferences while popover open
- [ ] No conflicts

## 🎯 Performance Testing

### Resource Usage
- [ ] Open Activity Monitor
- [ ] Launch SystemBadge
- [ ] Check memory usage (~20-25 MB with glass)
- [ ] Check CPU usage (minimal)
- [ ] Open and close popover multiple times
- [ ] No sustained high CPU usage

### Responsiveness
- [ ] Popover opens instantly (<100ms)
- [ ] Preferences opens instantly
- [ ] Settings changes apply quickly
- [ ] No lag when scrolling metrics
- [ ] Glass effect renders smoothly

### Battery Impact
- [ ] Check Energy Impact in Activity Monitor
- [ ] Should be "Low" or "Very Low"
- [ ] No significant battery drain

## 📱 Platform Compatibility

### macOS 13 (Ventura)
- [ ] App runs on macOS 13.0+
- [ ] Glass effect works
- [ ] All features functional

### macOS 14 (Sonoma)
- [ ] App runs on macOS 14.0+
- [ ] Glass effect works
- [ ] All features functional

### macOS 15 (Sequoia)
- [ ] App runs on macOS 15.0+
- [ ] Glass effect works
- [ ] All features functional

### Architecture
- [ ] Works on Intel Macs
- [ ] Works on Apple Silicon Macs

## 🐛 Bug Testing

### Known Edge Cases
- [ ] Invalid font name in storage → uses system font
- [ ] Corrupted color data → uses default colors
- [ ] Missing icon assets → shows placeholder
- [ ] Network unavailable → public IP shows error gracefully

### Stress Testing
- [ ] Leave app running for extended period (1+ hour)
- [ ] Open/close popover 100+ times
- [ ] Change settings repeatedly
- [ ] Switch appearance modes repeatedly
- [ ] No crashes or memory issues

## ✅ Acceptance Criteria

### Must Have
- [x] App builds without errors
- [x] Glass effect visible and working
- [x] Light/dark mode adaptation works
- [x] Settings persist correctly
- [x] No crashes in normal use

### Should Have
- [x] Performance is good
- [x] All settings functional
- [x] Documentation is clear
- [x] Code is clean

### Nice to Have
- [x] Presets documented
- [x] Migration guide provided
- [x] Architecture documented
- [x] Quick start guide available

## 🎉 Final Verification

### User Experience
- [ ] App feels polished
- [ ] Glass effect looks professional
- [ ] Colors are readable in all modes
- [ ] Settings are intuitive
- [ ] No obvious bugs

### Developer Experience
- [ ] Code is well documented
- [ ] Architecture is clear
- [ ] Easy to extend
- [ ] Follows Swift/SwiftUI best practices

### Documentation
- [ ] README updated
- [ ] Theme guides present
- [ ] Code comments adequate
- [ ] Examples provided

## 🚀 Ready to Ship?

If all items are checked, the implementation is complete and ready!

### Pre-Ship Checklist
- [ ] All tests pass
- [ ] No known critical bugs
- [ ] Documentation complete
- [ ] Code reviewed
- [ ] Version number updated
- [ ] Release notes written

### Ship It! 🎊
- [ ] Build release version
- [ ] Archive for distribution
- [ ] Test release build
- [ ] Deploy/distribute
- [ ] Celebrate! 🎉

---

## 📝 Notes Section

Use this space to record any issues found during testing:

```
Issue: [Description]
Steps to Reproduce: 
Expected: 
Actual: 
Severity: Critical/High/Medium/Low
Status: Fixed/Open
```

---

## 🎓 Testing Tips

### Efficient Testing
1. Test in order (top to bottom)
2. Mark items as you go
3. Note any issues immediately
4. Retest after fixes

### What to Watch For
- Visual glitches
- Crashes or hangs
- Memory leaks
- Performance issues
- Inconsistent behavior

### Tools to Use
- Activity Monitor (performance)
- Console.app (crash logs)
- Xcode Instruments (profiling)
- Your eyes (visual inspection)

---

**Happy Testing! 🧪**

When all checkboxes are complete, your implementation is production-ready!
