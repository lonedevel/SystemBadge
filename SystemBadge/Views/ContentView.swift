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
	let minWidth : CGFloat = 750
	let minHeight : CGFloat = 700
	let maxWidth : CGFloat = 750
	let maxHeight : CGFloat = 700
}

struct ContentView: View {
	@ObservedObject private var statusInfo: StatusInfo = StatusInfo()
	@ObservedObject var badge: BadgeInfo
	
//	let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
	
	var body: some View {

		Group() {
			Spacer(minLength: 20.0)
			VStack {
				TitleText(text: badge.name)
				VStack(spacing: 5) {
					ScrollView {
						ForEach(statusInfo.statusEntries.indices) { i in
							VStack {
								let entry = statusInfo.statusEntries[i]
									StatusEntryView(name: entry.name, value: entry.commandValue(), icon: entry.icon)
								Divider()
							}
						}
					}
				}
			}
			Spacer(minLength: 20.0)
		}
		.frame(minWidth: windowSize().minWidth,
			   maxWidth: windowSize().maxWidth,
			   minHeight: windowSize().minHeight,
			   maxHeight: windowSize().maxHeight)
    }
	
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(badge: BadgeInfo())
    }
}
