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
        self.popover.contentSize = NSSize(width: windowSize.maxWidth, height: windowSize.maxHeight)
        self.popover.behavior = .transient
        self.popover.animates = true
		
		// Use standard hosting controller - glass effect is now in SwiftUI
		let hostingController = NSHostingController(rootView: contentView)
		
		// Configure hosting controller for stable rendering
		hostingController.view.wantsLayer = true
		
		self.popover.contentViewController = hostingController
		
        // Configure popover appearance after showing
        DispatchQueue.main.async {
            if let popoverWindow = self.popover.contentViewController?.view.window {
                // Ensure the popover window is stable
                popoverWindow.isMovable = false
                popoverWindow.level = .popUpMenu
            }
        }
		
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
                DispatchQueue.main.async {
                    let enableGlass = UserDefaults.standard.object(forKey: "enableLiquidGlass") as? Bool ?? true
                    WindowConfigurator.configurePopoverForGlassEffect(self.popover, enableGlass: enableGlass)
                }
            }
        }
    }
}
