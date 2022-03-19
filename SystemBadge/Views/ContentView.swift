//
//  ContentView.swift
//  SystemBadge
//
//  Created by Richard Michaud on 1/29/22.
//

import SwiftUI

struct windowSize {
	// change let to static - read comments
	let minWidth : CGFloat = 1000
	let minHeight : CGFloat = 700
	let maxWidth : CGFloat = 1000
	let maxHeight : CGFloat = 700
}

struct ContentView: View {
	@State private var statusInfo: StatusInfo = StatusInfo()
	
	var body: some View {
		Group() {
			Spacer(minLength: 20.0)
			VStack {
				TitleText(text: "System Information")
				VStack(spacing: 10) {
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
        ContentView()
    }
}
