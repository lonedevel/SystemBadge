//
//  PreferencesView.swift
//  SystemBadge
//
//  Created by Richard Michaud on 3/19/22.
//

import SwiftUI

struct PreferencesView: View {
	@State private var metricFont: NSFont = NSFont.systemFont(ofSize: 12)

    var body: some View {
		TabView {
			AppearanceSettingsView()
				.tabItem{
					Label("Appearance", systemImage: "paintpalette")
				}
			ContentSettingsView()
				.tabItem{
					Label("Content", systemImage: "gear")
				}
		}
		.padding(20)
		.frame(width: 375, height: 300)
	}
}

struct AppearanceSettingsView: View {
	@AppStorage("metricColor") private var metricColor = Color("MetricColor")
	@AppStorage("labelColor") private var labelColor = Color("LabelColor")
	@AppStorage("backgroundColor") private var backgroundColor = Color("BackgroundColor")
	@State private var metricFont: NSFont = NSFont.systemFont(ofSize: 24)

//	@AppStorage("metricFont") private var metricFont = Font("MetricFont")
//	var metricFont: Font
	
	var body: some View {
		Form {
			FontPicker("Metric Font", selection: $metricFont)
			Text("selected font name \(metricFont.displayName ?? "no font" )")
			ColorPicker("Metric Color", selection: $metricColor)
			ColorPicker("Label Color", selection: $labelColor)
			ColorPicker("Background Color", selection: $backgroundColor)
		}
	}
}

struct ContentSettingsView: View {
	@AppStorage("showCpu") private var showCpu = true
	@AppStorage("showPublicInternet") private var showPublicInternet = true
	
	var body: some View {
		Form {
			Toggle("Show CPU", isOn: $showCpu)
			Toggle("Show Public Internet", isOn: $showPublicInternet)
//			Toggle("Show CPU", isOn: $showCpu)
//			Toggle("Show CPU", isOn: $showCpu)
			
		}
	}
}


struct PreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        PreferencesView()
    }
}
