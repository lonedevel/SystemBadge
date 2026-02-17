# Quick Start: Theming & Liquid Glass

## 🎯 TL;DR - Getting Started in 30 Seconds

1. **Launch SystemBadge** - Click the menu bar icon
2. **Open Preferences** - Press ⌘, or select from menu
3. **Choose your style** - Pick one of the presets below
4. **Done!** - Changes apply immediately

## 🎨 Recommended Presets

### 1. Modern Glass (Default) ✨
**Perfect for**: Most users, modern aesthetic lovers
```
Appearance Tab:
  ✓ Use System Colors
  ✓ Enable Liquid Glass

Glass Effect Tab:
  ✓ Enable Liquid Glass Effect
  Corner Radius: 16
  ☐ Enable Glass Tint
```

**Result**: Clean, modern popover that adapts to your system theme with subtle blur and light effects.

---

### 2. Vibrant Blue Glass 💙
**Perfect for**: Personality, visual pop
```
Appearance Tab:
  ✓ Use System Colors
  ✓ Enable Liquid Glass

Glass Effect Tab:
  ✓ Enable Liquid Glass Effect
  Corner Radius: 16
  ✓ Enable Glass Tint
  Tint Color: System Blue
```

**Result**: Same as Modern Glass but with a subtle blue tint that adds character.

---

### 3. Sharp & Clean 📐
**Perfect for**: Minimalists, traditional UI fans
```
Appearance Tab:
  ✓ Use System Colors
  ✓ Enable Liquid Glass

Glass Effect Tab:
  ✓ Enable Liquid Glass Effect
  Corner Radius: 8
  ☐ Enable Glass Tint
```

**Result**: Liquid Glass effect with sharp corners for a more business-like appearance.

---

### 4. Maximum Roundness 🔵
**Perfect for**: Soft, friendly aesthetic
```
Appearance Tab:
  ✓ Use System Colors
  ✓ Enable Liquid Glass

Glass Effect Tab:
  ✓ Enable Liquid Glass Effect
  Corner Radius: 28
  ☐ Enable Glass Tint
```

**Result**: Very rounded corners creating a softer, more approachable look.

---

### 5. Custom Traditional 🎨
**Perfect for**: Those who prefer solid colors over glass
```
Appearance Tab:
  ☐ Use System Colors
  ☐ Enable Liquid Glass
  Set your custom colors

Glass Effect Tab:
  ☐ Enable Liquid Glass Effect
```

**Result**: Traditional solid background with your choice of colors. Glass effects disabled.

---

## 💡 Pro Tips

### Automatic Light/Dark Switching
- SystemBadge automatically adapts when you switch macOS appearance
- No need to configure anything - it just works!
- Toggle: **System Settings → Appearance → Light/Dark**

### Best Tint Colors
For glass tints, these colors work best:
- **Blues**: System Blue, Azure, Cyan
- **Greens**: Mint, Teal
- **Purples**: Purple, Indigo
- **Avoid**: Bright reds, oranges (too intense)

### Performance
- Glass effects are GPU-accelerated
- No noticeable performance impact on modern Macs (2018+)
- Older Macs: Disable glass if you experience lag

## 🔧 Quick Troubleshooting

### "I don't see the glass effect"
1. Check that "Enable Liquid Glass" is ON in both tabs
2. Close and reopen the popover (click menu icon)
3. Ensure you're running macOS 13.0 or later

### "My custom colors aren't showing"
1. Turn OFF "Use System Colors" in Appearance tab
2. Turn OFF "Enable Liquid Glass" to control background
3. Set your custom colors
4. Close and reopen popover

### "Tint color isn't visible"
1. Tints are intentionally subtle
2. Try more saturated colors for more visible effect
3. Works best against varied backgrounds (not solid desktops)

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘, | Open Preferences |
| ⌘W | Close Preferences |
| Click Menu Icon | Open/Close Popover |

## 🎓 Learn More

- **Full Documentation**: See [THEMING_GUIDE.md](THEMING_GUIDE.md)
- **Implementation Details**: See [THEME_IMPLEMENTATION.md](THEME_IMPLEMENTATION.md)
- **General Info**: See [README.md](README.md)

## 📸 Visual Comparison

### Light Mode
```
┌─────────────────────┐
│  Modern Glass       │  Blurred, light, translucent
│  Sharp & Clean      │  Clean edges, professional
│  Custom Traditional │  Solid color, no effects
└─────────────────────┘
```

### Dark Mode
```
┌─────────────────────┐
│  Modern Glass       │  Blurred, dark, translucent
│  Sharp & Clean      │  Clean edges, dark theme
│  Custom Traditional │  Solid dark color
└─────────────────────┘
```

## 🚀 Advanced: Creating Your Own Preset

Want something unique? Mix and match:

1. **Start with a preset** above as base
2. **Adjust corner radius** (0 = square, 32 = pill-shaped)
3. **Experiment with tints** (subtle is better)
4. **Test in both light and dark mode**
5. **Share your preset!** (Open an issue on GitHub)

---

**Questions?** Check the full [THEMING_GUIDE.md](THEMING_GUIDE.md) or open an issue on GitHub.

**Enjoy your personalized SystemBadge!** 🎉
