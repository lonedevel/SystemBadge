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
			ContentSettingsView()
				.tabItem{
					Label("Content", systemImage: "gear")
				}
		}
		.padding(20)
		.frame(width: 375, height: 150)
	}
}

struct AppearanceSettingsView: View {
	@AppStorage("showCpu") private var showCpu = true

	var body: some View {
		Form {
			Text("Appearance Settings")
				.font(.title)
			Toggle("Show CPU", isOn: $showCpu)
		}
	}
}

struct ContentSettingsView: View {
	var body: some View {
		Text("Content Settings")
			.font(.title)
	}
}


struct PreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        PreferencesView()
    }
}
