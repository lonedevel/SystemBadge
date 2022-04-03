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
	var badgeInfo = BadgeInfo()


	func listInstalledFonts() {
		  let fontFamilies = NSFontManager.shared.availableFontFamilies.sorted()
		  for family in fontFamilies {
			  print(family)
			  let familyFonts = NSFontManager.shared.availableMembers(ofFontFamily: family)
			  if let fonts = familyFonts {
				  for font in fonts {
					print("\t\(font)")
				  }
			  }
		  }
	  }
	
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
//		listInstalledFonts()	
		
		let contentView = ContentView(badge: badgeInfo)

		// Create the popover
		self.popover = NSPopover()
		self.popover.contentSize = NSSize(width: 750, height: 250)
		
		self.popover.behavior = .transient
//		self.popover.animates = false
		self.popover.contentViewController = NSHostingController(rootView: contentView)
		
		self.statusBarItem = NSStatusBar.system.statusItem(withLength: CGFloat(NSStatusItem.variableLength))
		if let button = self.statusBarItem.button {
			button.image = NSImage(named:"Icon")
//			button.image?.size = NSSize(width: 18.0, height: 18.0)
//			button.image?.isTemplate = true
			
			button.action = #selector(AppDelegate.togglePopover(_:))
		}
		
//		self.statusBarItem.menu =
		
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
