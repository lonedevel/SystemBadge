//
//  ContentView.swift
//  SystemBadge
//
//  Created by Richard Michaud on 1/29/22.
//

import SwiftUI
import Combine


class BadgeInfo: ObservableObject {
	@Published var name: String
	init() {
		name = "System Badge"
	}
}
struct windowSize {
	// change let to static - read comments
	static let minWidth : CGFloat = 650
	static let minHeight : CGFloat = 200
	static let maxWidth : CGFloat = 650
	static let maxHeight : CGFloat = 250
}

struct ContentView: View {
	@StateObject private var statusInfo = StatusInfo()
	@AppStorage("backgroundColor") private var backgroundColor = Color("BackgroundColor")
	@AppStorage("enableLiquidGlass") private var enableLiquidGlass = true
	@AppStorage("useSystemColors") private var useSystemColors = true
	@AppStorage("glassCornerRadius") private var glassCornerRadius = 16.0
	@AppStorage("glassTintColor") private var glassTintColorData: Data?
	@Environment(\.colorScheme) private var colorScheme
	@ObservedObject var badge: BadgeInfo
	
	// Dynamic background based on appearance and settings
	private var dynamicBackground: Color {
		if enableLiquidGlass {
			// When Liquid Glass is enabled, use a more transparent background
			return Color.clear
		} else if useSystemColors {
			// Use system-adaptive colors
			return colorScheme == .dark ? Color(NSColor.windowBackgroundColor) : Color(NSColor.controlBackgroundColor)
		} else {
			// Use custom color
			return backgroundColor
		}
	}
	
	// Extract tint color from stored data
	private var glassTintColor: Color? {
		guard let colorData = glassTintColorData,
			  let nsColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData) else {
			return nil
		}
		return Color(nsColor)
	}
	
	var body: some View {
		if !enableLiquidGlass {
			// Only show background when glass is disabled
			dynamicBackground.ignoresSafeArea()
		}
		
		
		GlassEffectContainer() {
			ZStack {
				// Background layer
				
				// Content layer
				TabView {
					VStack(spacing: 5) {
						ScrollView {
							ForEach(statusInfo.statusEntries.filter{ $0.category.contains("General") }) { (item) in
								VStack {
									StatusEntryView(name: item.name, value: item.value, icon: item.icon)

								}
							}
						}
						.glassEffect(.regular.tint(glassTintColor).interactive(), in: .rect(cornerRadius: 10.0))
					}
					.tabItem{
						Label("General", systemImage: "paintpalette")
					}
					VStack(spacing: 5) {
						ScrollView {
							ForEach(statusInfo.statusEntries.filter{ $0.category.contains("Network") }) { (item) in
								VStack {
									StatusEntryView(name: item.name, value: item.value, icon: item.icon)
//										.glassEffect(.regular.tint(glassTintColor).interactive(), in: .rect(cornerRadius: 16.0))
								}
							}
						}
						.glassEffect(.regular.tint(glassTintColor).interactive(), in: .rect(cornerRadius: 10.0))
					}
					.tabItem{
						Label("Network", systemImage: "network")
					}
					VStack(spacing: 5) {
						ScrollView {
							ForEach(statusInfo.statusEntries.filter{ $0.category.contains("System") }) { (item) in
								VStack {
									StatusEntryView(name: item.name, value: item.value, icon: item.icon)
								}
							}
						}
						.glassEffect(.regular.tint(glassTintColor).interactive(), in: .rect(cornerRadius: 10.0))
					}
					.tabItem{
						Label("System", systemImage: "desktopcomputer")
					}
					VStack(spacing: 5) {
						ScrollView {
							ForEach(statusInfo.statusEntries.filter{ $0.category.contains("Power") }) { (item) in
								VStack {
									StatusEntryView(name: item.name, value: item.value, icon: item.icon)
								}
							}
						}
						.glassEffect(.regular.tint(glassTintColor).interactive(), in: .rect(cornerRadius: 10.0))
					}
					.tabItem{
						Label("Power", systemImage: "bolt.fill")
					}
					VStack(spacing: 5) {
						ScrollView {
							ForEach(statusInfo.statusEntries.filter{ $0.category.contains("Storage") }) { (item) in
								VStack {
									StatusEntryView(name: item.name, value: item.value, icon: item.icon)
								}
							}
						}
						.glassEffect(.regular.tint(glassTintColor).interactive(), in: .rect(cornerRadius: 10.0))
					}
					.tabItem{
						Label("Storage", systemImage: "internaldrive")
					}
				}
			}
		}
		.padding(20)
		.frame(minWidth: windowSize.minWidth,
			   maxWidth: windowSize.maxWidth,
			   minHeight: windowSize.minHeight,
			   maxHeight: windowSize.maxHeight)
//		.glassEffect(.regular.tint(glassTintColor).interactive(), in: .rect(cornerRadius: 16.0))
	}
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(badge: BadgeInfo())
    }
}
