//
//  PreferencesView.swift
//  SystemBadge
//
//  Created by Richard Michaud on 3/19/22.
//

import SwiftUI

struct PreferencesView: View {
    var body: some View {
		TabView {
			AppearanceSettingsView()
				.tabItem{
					Label("Appearance", systemImage: "paintpalette")
				}
			GlassEffectSettingsView()
				.tabItem{
					Label("Glass Effect", systemImage: "sparkles")
				}
			ContentSettingsView()
				.tabItem{
					Label("Content", systemImage: "gear")
				}
		}
		.padding(20)
		.frame(width: 450, height: 400)
	}
}

struct AppearanceSettingsView: View {
	@AppStorage("metricColor") private var metricColor = Color("MetricColor")
	@AppStorage("labelColor") private var labelColor = Color("LabelColor")
	@AppStorage("backgroundColor") private var backgroundColor = Color("BackgroundColor")
	@AppStorage("useSystemColors") private var useSystemColors = true
	@AppStorage("enableLiquidGlass") private var enableLiquidGlass = true
	@State private var metricFont: NSFont = NSFont.systemFont(ofSize: 24)
	@Environment(\.colorScheme) private var colorScheme

	var body: some View {
		Form {
			Section("Theme") {
				Toggle("Use System Colors", isOn: $useSystemColors)
					.help("Automatically adapt to light and dark mode")
				
				Toggle("Enable Liquid Glass", isOn: $enableLiquidGlass)
					.help("Apply modern glass effect to the popover")
				
				Text(colorScheme == .dark ? "Current: Dark Mode" : "Current: Light Mode")
					.font(.caption)
					.foregroundColor(.secondary)
			}
			
			Section("Custom Colors") {
				FontPicker("Metric Font", selection: $metricFont)
				Text("Selected font: \(metricFont.displayName ?? "System Font")")
					.font(.caption)
					.foregroundColor(.secondary)
				
				ColorPicker("Metric Color", selection: $metricColor)
					.disabled(useSystemColors && enableLiquidGlass)
				
				ColorPicker("Label Color", selection: $labelColor)
					.disabled(useSystemColors && enableLiquidGlass)
				
				ColorPicker("Background Color", selection: $backgroundColor)
					.disabled(enableLiquidGlass)
				
				if useSystemColors || enableLiquidGlass {
					Text("Some color options are disabled when using system colors or Liquid Glass")
						.font(.caption)
						.foregroundColor(.secondary)
				}
			}
		}
	}
}

struct GlassEffectSettingsView: View {
	@AppStorage("enableLiquidGlass") private var enableLiquidGlass = true
	@AppStorage("glassCornerRadius") private var glassCornerRadius = 16.0
	@AppStorage("glassTintColor") private var glassTintColorData: Data?
	@State private var glassTintColor: Color = .clear
	@State private var enableTint = false
	
	var body: some View {
		Form {
			Section("Liquid Glass Settings") {
				Toggle("Enable Liquid Glass Effect", isOn: $enableLiquidGlass)
					.help("Apply a dynamic glass material to the popover")
				
				if enableLiquidGlass {
					VStack(alignment: .leading) {
						Text("Corner Radius: \(Int(glassCornerRadius))")
						Slider(value: $glassCornerRadius, in: 0...32, step: 1)
							.help("Adjust the roundness of the glass effect corners")
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
								// Convert SwiftUI Color to NSColor and save
								let nsColor = NSColor(newValue).withAlphaComponent(0.3)
								if let data = try? NSKeyedArchiver.archivedData(withRootObject: nsColor, requiringSecureCoding: false) {
									glassTintColorData = data
								}
							}
						
						Text("Tint colors are applied subtly for best effect")
							.font(.caption)
							.foregroundColor(.secondary)
					}
				}
			}
			
			Section("About Liquid Glass") {
				Text("Liquid Glass is a dynamic material that:")
					.font(.headline)
				
				VStack(alignment: .leading, spacing: 8) {
					Label("Blurs content behind it", systemImage: "wand.and.stars")
					Label("Reflects surrounding light and color", systemImage: "light.max")
					Label("Creates a modern, immersive interface", systemImage: "sparkles")
				}
				.font(.caption)
				.foregroundColor(.secondary)
			}
			
			Section("Tips") {
				VStack(alignment: .leading, spacing: 8) {
					Text("• For best results, disable custom background colors")
					Text("• Subtle tints work better than bright colors")
					Text("• The effect adapts to light and dark mode automatically")
				}
				.font(.caption)
				.foregroundColor(.secondary)
			}
		}
	}
}

struct ContentSettingsView: View {
	@AppStorage("showCpu") private var showCpu = true
	@AppStorage("showPublicInternet") private var showPublicInternet = true
	
	var body: some View {
		Form {
			Section("Display Options") {
				Toggle("Show CPU", isOn: $showCpu)
				Toggle("Show Public Internet", isOn: $showPublicInternet)
			}
			
			Section("Storage") {
				Text("All mounted volumes are automatically detected and displayed.")
					.font(.caption)
					.foregroundColor(.secondary)
			}
		}
	}
}


struct PreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        PreferencesView()
			.frame(width: 450, height: 400)
    }
}
