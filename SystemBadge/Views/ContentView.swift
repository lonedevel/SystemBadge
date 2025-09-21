//
//  ContentView.swift
//  SystemBadge
//
//  Created by Richard Michaud on 1/29/22.
//

import SwiftUI

class BadgeInfo: ObservableObject {
	@Published var name: String
	init() {
		name = "System Badge"
	}
}
struct windowSize {
	// change let to static - read comments
	let minWidth : CGFloat = 650
	let minHeight : CGFloat = 200
	let maxWidth : CGFloat = 620
	let maxHeight : CGFloat = 250
}

struct ContentView: View {
	let statusInfo = StatusInfo()
	@AppStorage("backgroundColor") private var backgroundColor = Color("BackgroundColor")

	@ObservedObject var badge: BadgeInfo
	
	var body: some View {
		ZStack {
			$backgroundColor.wrappedValue.ignoresSafeArea()
			TabView {
				VStack(spacing: 5) {
					ScrollView {
						ForEach(statusInfo.statusEntries.filter{$0.category.contains("General")}) { (item) in
							VStack {
								StatusEntryView(name: item.name, value: item.commandValue(), icon: item.icon)
							}
						}
					}
				}
				.tabItem{
					Label("General", systemImage: "paintpalette")
				}
				VStack(spacing: 5) {
					ScrollView {
						ForEach(statusInfo.statusEntries.filter{$0.category.contains("Network")}) { (item) in
							VStack {
								StatusEntryView(name: item.name, value: item.commandValue(), icon: item.icon)
							}
						}
					}
				}
				.tabItem{
						Label("Network", systemImage: "gear")
				}
				VStack(spacing: 5) {
					ScrollView {
						ForEach(statusInfo.statusEntries.filter{$0.category.contains("System")}) { (item) in
							VStack {
								StatusEntryView(name: item.name, value: item.commandValue(), icon: item.icon)
							}
						}
					}
				}
				.tabItem{
					Label("System", systemImage: "gear")
				}
			}
		}
		

		.padding(20)
//		.frame(width: 375, height: 150)
		.frame(minWidth: windowSize().minWidth,
			   maxWidth: windowSize().maxWidth,
			   minHeight: windowSize().minHeight,
			   maxHeight: windowSize().maxHeight)

//		Group() {
//			Spacer(minLength: 20.0)
//			VStack {
//				TitleText(text: badge.name)
//				VStack(spacing: 5) {
//					ScrollView {
//						ForEach(statusInfo.statusEntries.indices) { i in
//							VStack {
//								let entry = statusInfo.statusEntries[i]
//									StatusEntryView(name: entry.name, value: entry.commandValue(), icon: entry.icon)
//								Divider()
//							}
//						}
//					}
//				}
//			}
//			Spacer(minLength: 20.0)
//		}
//		.frame(minWidth: windowSize().minWidth,
//			   maxWidth: windowSize().maxWidth,
//			   minHeight: windowSize().minHeight,
//			   maxHeight: windowSize().maxHeight)
    }
	
}

//struct GeneralBadgeView: View {
//
//	var body: some View {
//		Text("General")
//			.font(.title)
//	}
//}
//
//
//struct SystemBadgeView: View {
//	var body: some View {
//		Text("System")
//			.font(.title)
//	}
//}
//
//struct NetworkBadgeView: View {
//	var body: some View {
//		Text("Network")
//			.font(.title)
//	}
//}


//struct AppearanceSettingsView: View {
//@AppStorage("showCpu") private var showCpu = true
//
//var body: some View {
//Form {
//	Text("Appearance Settings")
//		.font(.title)
//	Toggle("Show CPU", isOn: $showCpu)
//}
//}
//}
//
//struct ContentSettingsView: View {
//var body: some View {
//Text("Content Settings")
//	.font(.title)
//}
//}



struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(badge: BadgeInfo())
    }
}
