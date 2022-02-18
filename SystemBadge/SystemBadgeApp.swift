//
//  SystemBadgeApp.swift
//  SystemBadge
//
//  Created by Richard Michaud on 2/1/22.
//

import SwiftUI

@main
struct SystemBadgeApp: App {
	@NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
