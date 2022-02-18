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
class AppDelegate: NSObject, NSApplicationDelegate {

	var popover: NSPopover!
	var statusBarItem: NSStatusItem!

	
	func applicationDidFinishLaunching(_ aNotification: Notification) {
		// Create the SwiftUI view that provides the window contents.
	
//		for family in UIFont.familyNames.sorted() {
//			let names = UIFont.fontNames(forFamilyName: family)
//			print("Family: \(family) Font names: \(names)")
//		}
		
//		for family in NSFontManager.shared.availableFontFamilies {
//			let names = NSFontManager.shared.availableMembers(ofFontFamily: family)
//			print("Family: \(family) Font names: \(names)")
//		}
		
		let contentView = ContentView()

		// Create the popover
		let popover = NSPopover()
		popover.contentSize = NSSize(width: 400, height: 500)
		popover.behavior = .transient
		popover.contentViewController = NSHostingController(rootView: contentView)
		self.popover = popover
		
		self.statusBarItem = NSStatusBar.system.statusItem(withLength: CGFloat(NSStatusItem.variableLength))
		if let button = self.statusBarItem.button {
			button.image = NSImage(named:"Icon")
//			button.image?.size = NSSize(width: 18.0, height: 18.0)
//			button.image?.isTemplate = true
			
			button.action = #selector(togglePopover(_:))
		}
		
//		self.statusBarItem.menu =
		
	}
	
	// Create the status item
	@objc func togglePopover(_ sender: AnyObject?) {
		_ = ContentView()

		 if let button = self.statusBarItem.button {
			  if self.popover.isShown {
				   self.popover.performClose(sender)
			  } else {
				  self.popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
			  }
		 }
	}
}
