//
//  AppDelegate.swift
//  SystemBadge
//
//  Created by Richard Michaud on 1/30/22.
//

import Cocoa
import AppKit
import SwiftUI

//@NSApplicationMain
@available(macOS 26.0, *)
class AppDelegate: NSObject, NSApplicationDelegate {

	var popover: NSPopover!
	var statusBarItem: NSStatusItem!
	var badgeInfo = BadgeInfo()
	
	func applicationDidFinishLaunching(_ aNotification: Notification) {
		// Create the SwiftUI view that provides the window contents.
		let contentView = ContentView(badge: badgeInfo)

		// Create the popover
		self.popover = NSPopover()
		self.popover.contentSize = NSSize(width: 650, height: 250)
		self.popover.behavior = .transient
		
		// Use standard hosting controller - glass effect is now in SwiftUI
		let hostingController = NSHostingController(rootView: contentView)
		self.popover.contentViewController = hostingController
		
		self.statusBarItem = NSStatusBar.system.statusItem(withLength: CGFloat(NSStatusItem.variableLength))
		if let button = self.statusBarItem.button {
			button.image = NSImage(named:"Icon")
			button.action = #selector(AppDelegate.togglePopover(_:))
		}
	}
	
	// Create the status item
	@objc func togglePopover(_ sender: AnyObject?) {
		_ = ContentView(badge: badgeInfo)

		 if let button = self.statusBarItem.button {
			  if self.popover.isShown {
				   self.popover.performClose(sender)
			  } else {
				  badgeInfo.name = "System Badge"
				  self.popover.show(relativeTo: button.frame, of: button, preferredEdge: NSRectEdge.minY)
			  }
		 }
	}
}

