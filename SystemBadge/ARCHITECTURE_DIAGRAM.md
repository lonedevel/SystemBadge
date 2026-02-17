# SystemBadge Theme Architecture Diagram

## Component Hierarchy

```
┌─────────────────────────────────────────────────────────┐
│                    SystemBadgeApp                       │
│                  (App Entry Point)                      │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ├─────────────────┐
                       │                 │
                       ▼                 ▼
          ┌────────────────────┐  ┌─────────────────┐
          │    AppDelegate     │  │ PreferencesView │
          │  (Menu Bar Host)   │  │   (Settings)    │
          └────────┬───────────┘  └─────────────────┘
                   │                       │
                   │                       ├─ AppearanceSettingsView
                   │                       ├─ GlassEffectSettingsView
                   │                       └─ ContentSettingsView
                   │
                   ▼
       ┌────────────────────────┐
       │ GlassHostingController │
       │ (Custom NSHosting)     │
       └────────┬───────────────┘
                │
    ┌───────────┴───────────┐
    │                       │
    ▼                       ▼
┌──────────────┐    ┌──────────────────┐
│ NSGlassView  │    │   ContentView    │
│ (Behind)     │    │   (SwiftUI)      │
└──────────────┘    └────────┬─────────┘
                             │
                             ├─ TabView
                             │   ├─ General Tab
                             │   ├─ Network Tab
                             │   ├─ System Tab
                             │   ├─ Power Tab
                             │   └─ Storage Tab
                             │
                             └─ StatusEntryView (repeated)
```

## Theme Data Flow

```
┌──────────────────────────────────────────────────────┐
│                  User Action                         │
│  (Toggle switch, adjust slider, pick color)          │
└─────────────────┬────────────────────────────────────┘
                  │
                  ▼
         ┌────────────────┐
         │   @AppStorage  │
         │  (UserDefaults)│
         └────────┬───────┘
                  │
       ┌──────────┴──────────┐
       │                     │
       ▼                     ▼
┌──────────────┐      ┌──────────────┐
│ View Layer   │      │ AppKit Layer │
│ (SwiftUI)    │      │ (NSKit)      │
└──────┬───────┘      └──────┬───────┘
       │                     │
       ▼                     ▼
 Automatic Re-render    NSGlassEffectView
 of SwiftUI views       property updates
```

## Color Selection Logic Tree

```
                        Start
                          │
                          ▼
                Is Liquid Glass Enabled?
                    ┌─────┴─────┐
                   YES          NO
                    │            │
                    ▼            ▼
             Use Primary/   Is System Colors
             Secondary        Enabled?
                              ┌──┴──┐
                             YES    NO
                              │      │
                              ▼      ▼
                      Adaptive      Custom
                      System        User-Set
                      Colors        Colors
```

## Glass Effect Rendering

```
┌─────────────────────────────────────────────────────┐
│                   Popover Window                    │
│                                                     │
│  ┌───────────────────────────────────────────┐    │
│  │         NSGlassEffectView (Layer 0)       │    │
│  │  • Blurs content behind popover           │    │
│  │  • Reflects ambient light                 │    │
│  │  • Optional tint color                    │    │
│  │  • Corner radius applied                  │    │
│  └───────────────────────────────────────────┘    │
│                      ▲                             │
│  ┌──────────────────┼──────────────────────┐      │
│  │    SwiftUI Content (Layer 1)            │      │
│  │                   │                      │      │
│  │  ┌────────────────┼────────────────┐    │      │
│  │  │      TabView    │                │    │      │
│  │  │  ┌──────────────▼────────────┐  │    │      │
│  │  │  │ StatusEntryView (Loop)    │  │    │      │
│  │  │  │  • Icon (yellow)          │  │    │      │
│  │  │  │  • Label (theme adaptive) │  │    │      │
│  │  │  │  • Value (theme adaptive) │  │    │      │
│  │  │  └───────────────────────────┘  │    │      │
│  │  └─────────────────────────────────┘    │      │
│  └──────────────────────────────────────────┘      │
│                                                     │
└─────────────────────────────────────────────────────┘
```

## Settings Persistence Architecture

```
┌─────────────────────────────────────────────┐
│            UserDefaults Storage             │
├─────────────────────────────────────────────┤
│                                             │
│  Theme Settings:                            │
│  ├─ useSystemColors: Bool                   │
│  ├─ enableLiquidGlass: Bool                 │
│  ├─ metricColor: Color (encoded)            │
│  ├─ labelColor: Color (encoded)             │
│  └─ backgroundColor: Color (encoded)        │
│                                             │
│  Glass Settings:                            │
│  ├─ glassCornerRadius: Double (0-32)        │
│  └─ glassTintColor: Data? (NSColor encoded) │
│                                             │
│  Content Settings:                          │
│  ├─ showCpu: Bool                           │
│  └─ showPublicInternet: Bool                │
│                                             │
└──────────────┬──────────────────────────────┘
               │
               ├──→ @AppStorage in Views
               │    (Automatic sync)
               │
               └──→ Read by GlassHostingController
                    (On viewDidLoad/viewWillAppear)
```

## Appearance Change Detection

```
         macOS System Appearance Change
                     │
                     ▼
    NSApplication.didChangeScreenParameters
              Notification Posted
                     │
                     ▼
         AppDelegate observes notification
                     │
                     ▼
    GlassHostingController.updateAppearance()
                     │
                     ▼
         setupGlassEffect() called again
                     │
        ┌────────────┴────────────┐
        │                         │
        ▼                         ▼
  NSGlassEffectView         SwiftUI Views
  recreated with           @Environment(\.colorScheme)
  new settings             triggers re-render
        │                         │
        └────────────┬────────────┘
                     │
                     ▼
            UI Updates Complete
         (Glass + Colors refreshed)
```

## View Communication Pattern

```
┌────────────────────────────────────────────┐
│          PreferencesView                   │
│  User toggles "Enable Liquid Glass"        │
└──────────────────┬─────────────────────────┘
                   │
                   ▼
         @AppStorage updates
         "enableLiquidGlass"
                   │
       ┌───────────┴───────────┐
       │                       │
       ▼                       ▼
┌────────────────┐    ┌────────────────┐
│  ContentView   │    │ GlassHosting   │
│  reads value   │    │ reads value    │
└───────┬────────┘    └───────┬────────┘
        │                     │
        ▼                     ▼
  Changes background    Recreates glass
  to transparent        effect or removes
                             │
                             └──→ Requires popover
                                  close/reopen to
                                  see full effect
```

## Thread Safety

```
┌─────────────────────────────────────┐
│        Main Thread (@MainActor)     │
├─────────────────────────────────────┤
│                                     │
│  • All SwiftUI Views                │
│  • @AppStorage reads/writes         │
│  • NSGlassEffectView manipulation   │
│  • NSHostingController lifecycle    │
│  • UserDefaults access              │
│  • Appearance notifications         │
│                                     │
│  All theme operations are           │
│  main-thread only (UI updates)      │
│                                     │
└─────────────────────────────────────┘

Note: StatusInfo uses actors for async
shell commands, but theme system is
entirely synchronous and main-thread.
```

## Performance Characteristics

```
Operation                    | Complexity | Performance
─────────────────────────────┼────────────┼────────────
Toggle setting               | O(1)       | Instant
@AppStorage update           | O(1)       | Instant
SwiftUI view re-render       | O(n)       | Fast (views)
NSGlassEffectView create     | O(1)       | Fast (GPU)
Color computation            | O(1)       | Instant
Appearance change detect     | O(1)       | Instant
Popover open with glass      | O(1)       | Smooth

Memory Usage:
  Base app:        ~15-20 MB
  With glass:      ~20-25 MB (GPU textures)
  Per preference:  <1 KB

GPU Usage:
  Without glass:   Minimal
  With glass:      Moderate (blur/reflection)
  Impact:          Negligible on modern GPUs
```

## Extension Points for Future Features

```
Current Architecture allows easy addition of:

1. More Glass Properties
   └─ Add to GlassEffectSettingsView
   └─ Add @AppStorage in GlassHostingController
   └─ Apply to NSGlassEffectView in setupGlassEffect()

2. Per-Tab Themes
   └─ Add ThemeConfig struct
   └─ Store per-category in UserDefaults
   └─ Read in each tab's VStack

3. Theme Presets
   └─ Create ThemePreset struct
   └─ Add preset picker in PreferencesView
   └─ Apply all settings at once

4. Export/Import Themes
   └─ Codable theme struct
   └─ File picker integration
   └─ JSON serialization

5. Live Preview
   └─ Add mini popover in PreferencesView
   └─ Mirror main popover appearance
   └─ Update in real-time
```

## Key Design Decisions

```
✓ Use @AppStorage directly in views
  → Automatic syncing, minimal boilerplate
  
✓ Separate GlassHostingController
  → Clean separation of AppKit/SwiftUI
  → Easy to enable/disable glass
  
✓ Computed properties for colors
  → Dynamic evaluation
  → No manual sync needed
  
✓ Transparent background with glass
  → Glass effect shows properly
  → No color conflicts
  
✓ Three-level color selection
  → Glass → System → Custom
  → Provides flexibility
  
✓ Appearance change observation
  → Automatic updates
  → No manual intervention
```

---

**Legend:**
- ┌─┐ └─┘ : Container/boundary
- ├─┤ : Connection/relationship  
- ▼ → : Data/control flow
- • : List item/feature

