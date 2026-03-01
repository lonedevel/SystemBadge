//
//  PreferencesView.swift
//  SystemBadge
//
//  Created by Richard Michaud on 3/19/22.
//

import SwiftUI

struct PreferencesView: View {
    @AppStorage("metricColor") private var metricColor = Color("MetricColor")
    @AppStorage("labelColor") private var labelColor = Color("LabelColor")
    @AppStorage("backgroundColor") private var backgroundColor = Color("BackgroundColor")
    @AppStorage("useSystemColors") private var useSystemColors = true
    @AppStorage("enableLiquidGlass") private var enableLiquidGlass = true
    @AppStorage("useCustomColorsWithGlass") private var useCustomColorsWithGlass = true
    @AppStorage("glassCornerRadius") private var glassCornerRadius = 16.0
    @AppStorage("glassTintColor") private var glassTintColorData: Data?
    @AppStorage("glassOpacity") private var glassOpacity = 85.0
    @AppStorage("showGeneralTab") private var showGeneralTab = true
    @AppStorage("showNetworkTab") private var showNetworkTab = true
    @AppStorage("showSystemTab") private var showSystemTab = true
    @AppStorage("showPowerTab") private var showPowerTab = true
    @AppStorage("showStorageTab") private var showStorageTab = true
    @AppStorage("showPerformanceTab") private var showPerformanceTab = true
    @State private var metricFont: NSFont = NSFont.systemFont(ofSize: 24)
    @State private var glassTintColor: Color = .clear
    @State private var enableTint = false
    @Environment(\.colorScheme) private var colorScheme

    private var dynamicBackground: Color {
        if enableLiquidGlass {
            return Color.clear
        }
        if useSystemColors {
            return colorScheme == .dark ? Color(NSColor.windowBackgroundColor) : Color(NSColor.controlBackgroundColor)
        }
        return backgroundColor
    }

    var body: some View {
        ZStack {
            if enableLiquidGlass {
                GlassEffectView(
                    cornerRadius: glassCornerRadius,
                    tintColor: enableTint ? NSColor(glassTintColor) : nil,
                    material: .contentBackground,
                    blendingMode: .withinWindow,
                    opacity: CGFloat(glassOpacity / 100.0)
                )
                .ignoresSafeArea()
            } else {
                dynamicBackground
                    .ignoresSafeArea()
            }

            TabView {
                ThemeSettingsTab(
                    useSystemColors: $useSystemColors,
                    enableLiquidGlass: $enableLiquidGlass,
                    useCustomColorsWithGlass: $useCustomColorsWithGlass,
                    glassOpacity: $glassOpacity,
                    glassCornerRadius: $glassCornerRadius,
                    enableTint: $enableTint,
                    glassTintColor: $glassTintColor,
                    glassTintColorData: $glassTintColorData
                )
                .tabItem {
                    Label("Theme", systemImage: "paintpalette")
                }

                ColorSettingsTab(
                    metricColor: $metricColor,
                    labelColor: $labelColor,
                    backgroundColor: $backgroundColor,
                    useSystemColors: $useSystemColors,
                    enableLiquidGlass: $enableLiquidGlass,
                    useCustomColorsWithGlass: $useCustomColorsWithGlass,
                    metricFont: $metricFont
                )
                .tabItem {
                    Label("Color", systemImage: "eyedropper.full")
                }

                ContentSettingsTab(
                    showGeneralTab: $showGeneralTab,
                    showNetworkTab: $showNetworkTab,
                    showSystemTab: $showSystemTab,
                    showPowerTab: $showPowerTab,
                    showStorageTab: $showStorageTab,
                    showPerformanceTab: $showPerformanceTab
                )
                .tabItem {
                    Label("Content", systemImage: "slider.horizontal.3")
                }
            }
            .padding(24)
        }
        .frame(width: 520, height: 460)
        .onAppear {
            if let colorData = glassTintColorData,
               let nsColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData) {
                glassTintColor = Color(nsColor)
                enableTint = true
            } else {
                enableTint = false
            }
        }
    }
}

struct ThemeSettingsTab: View {
    @Binding var useSystemColors: Bool
    @Binding var enableLiquidGlass: Bool
    @Binding var useCustomColorsWithGlass: Bool
    @Binding var glassOpacity: Double
    @Binding var glassCornerRadius: Double
    @Binding var enableTint: Bool
    @Binding var glassTintColor: Color
    @Binding var glassTintColorData: Data?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Form {
            Section("Theme") {
                Toggle("Use System Colors", isOn: $useSystemColors)
                    .help("Automatically adapt to light and dark mode")

                Toggle("Enable Liquid Glass", isOn: $enableLiquidGlass)
                    .help("Apply modern glass effect to the app windows")

                if enableLiquidGlass {
                    Toggle("Use Custom Colors With Liquid Glass", isOn: $useCustomColorsWithGlass)
                        .help("Allow metric and label colors when Liquid Glass is enabled")
                }

                Text(colorScheme == .dark ? "Current: Dark Mode" : "Current: Light Mode")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Glass") {
                if enableLiquidGlass {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Opacity: \(Int(glassOpacity))%")
                        Slider(value: $glassOpacity, in: 0...100, step: 1)
                            .help("Adjust glass intensity")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Corner Radius: \(Int(glassCornerRadius))")
                        Slider(value: $glassCornerRadius, in: 0...32, step: 1)
                            .help("Adjust the roundness of the glass corners")
                    }

                    Toggle("Enable Glass Tint", isOn: $enableTint)
                        .help("Add a subtle color tint to the glass effect")
                        .onChange(of: enableTint) { _, newValue in
                            if !newValue {
                                glassTintColorData = nil
                            }
                        }

                    if enableTint {
                        ColorPicker("Glass Tint Color", selection: $glassTintColor)
                            .onChange(of: glassTintColor) { _, newValue in
                                let nsColor = NSColor(newValue).withAlphaComponent(0.3)
                                if let data = try? NSKeyedArchiver.archivedData(withRootObject: nsColor, requiringSecureCoding: false) {
                                    glassTintColorData = data
                                }
                            }
                    }
                } else {
                    Text("Enable Liquid Glass to access glass appearance settings.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .environment(\.defaultMinListRowHeight, 34)
    }
}

struct ColorSettingsTab: View {
    @Binding var metricColor: Color
    @Binding var labelColor: Color
    @Binding var backgroundColor: Color
    @Binding var useSystemColors: Bool
    @Binding var enableLiquidGlass: Bool
    @Binding var useCustomColorsWithGlass: Bool
    @Binding var metricFont: NSFont

    var body: some View {
        Form {
            Section("Fonts") {
                FontPicker("Metric Font", selection: $metricFont)
            }

            Section("Colors") {
                ColorPicker("Metric Color", selection: $metricColor)
                    .disabled(useSystemColors || (enableLiquidGlass && !useCustomColorsWithGlass))

                ColorPicker("Label Color", selection: $labelColor)
                    .disabled(useSystemColors || (enableLiquidGlass && !useCustomColorsWithGlass))

                ColorPicker("Background Color", selection: $backgroundColor)
                    .disabled(enableLiquidGlass)
            }
        }
        .formStyle(.grouped)
        .environment(\.defaultMinListRowHeight, 34)
    }
}

struct ContentSettingsTab: View {
    @Binding var showGeneralTab: Bool
    @Binding var showNetworkTab: Bool
    @Binding var showSystemTab: Bool
    @Binding var showPowerTab: Bool
    @Binding var showStorageTab: Bool
    @Binding var showPerformanceTab: Bool

    var body: some View {
        Form {
            Section("Tabs") {
                Toggle("Show General Tab", isOn: $showGeneralTab)
                Toggle("Show Network Tab", isOn: $showNetworkTab)
                Toggle("Show System Tab", isOn: $showSystemTab)
                Toggle("Show Power Tab", isOn: $showPowerTab)
                Toggle("Show Storage Tab", isOn: $showStorageTab)
                Toggle("Show Performance Tab", isOn: $showPerformanceTab)
            }
        }
        .formStyle(.grouped)
        .environment(\.defaultMinListRowHeight, 34)
    }
}

struct PreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        PreferencesView()
            .frame(width: 520, height: 460)
    }
}
