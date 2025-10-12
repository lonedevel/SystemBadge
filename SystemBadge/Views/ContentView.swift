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
	@ObservedObject var badge: BadgeInfo
	
	var body: some View {
		ZStack {
			backgroundColor.ignoresSafeArea()
			TabView {
				VStack(spacing: 5) {
					ScrollView {
						ForEach(statusInfo.statusEntries.filter{ $0.category.contains("General") }) { (item) in
							VStack {
								StatusEntryView(name: item.name, value: item.value, icon: item.icon)
							}
						}
					}
				}
				.tabItem{
					Label("General", systemImage: "paintpalette")
				}
				VStack(spacing: 5) {
					ScrollView {
						ForEach(statusInfo.statusEntries.filter{ $0.category.contains("Network") }) { (item) in
							VStack {
								StatusEntryView(name: item.name, value: item.value, icon: item.icon)
							}
						}
					}
				}
				.tabItem{
					Label("Network", systemImage: "gear")
				}
				VStack(spacing: 5) {
					ScrollView {
						ForEach(statusInfo.statusEntries.filter{ $0.category.contains("System") }) { (item) in
							VStack {
								StatusEntryView(name: item.name, value: item.value, icon: item.icon)
							}
						}
					}
				}
				.tabItem{
					Label("System", systemImage: "gear")
				}
				VStack(spacing: 5) {
					ScrollView {
						ForEach(statusInfo.statusEntries.filter{ $0.category.contains("Power") }) { (item) in
							VStack {
								StatusEntryView(name: item.name, value: item.value, icon: item.icon)
							}
						}
					}
				}
				.tabItem{
					Label("Power", systemImage: "gear")
				}
				VStack(spacing: 5) {
					ScrollView {
						ForEach(statusInfo.statusEntries.filter{ $0.category.contains("Storage") }) { (item) in
							VStack {
								StatusEntryView(name: item.name, value: item.value, icon: item.icon)
							}
						}
					}
				}
				.tabItem{
					Label("Storage", systemImage: "gear")
				}
			}
		}
		.padding(20)
		.frame(minWidth: windowSize.minWidth,
			   maxWidth: windowSize.maxWidth,
			   minHeight: windowSize.minHeight,
			   maxHeight: windowSize.maxHeight)
	}
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(badge: BadgeInfo())
    }
}
