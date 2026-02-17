//
//  WindowConfigurator.swift
//  SystemBadge
//
//  Created by Richard Michaud
//

import AppKit
import SwiftUI

/// Helper class to configure window appearance for glass effects
class WindowConfigurator {
	
	/// Configure a window for glass effect display
	/// - Parameters:
	///   - window: The NSWindow to configure
	///   - enableGlass: Whether to enable glass effect mode
	static func configureForGlassEffect(_ window: NSWindow, enableGlass: Bool) {
		if enableGlass {
			// Make window transparent for glass effect
			window.isOpaque = false
			window.backgroundColor = .clear
			window.titlebarAppearsTransparent = true
			window.styleMask.insert(.fullSizeContentView)
			
			// Configure the window's content view for visual effects
			if let contentView = window.contentView {
				contentView.wantsLayer = true
				contentView.layer?.backgroundColor = .clear
			}
		} else {
			// Restore default window appearance
			window.isOpaque = true
			window.backgroundColor = NSColor.windowBackgroundColor
			window.titlebarAppearsTransparent = false
			window.styleMask.remove(.fullSizeContentView)
		}
	}
	
	/// Configure a popover for glass effect display
	/// - Parameters:
	///   - popover: The NSPopover to configure
	///   - enableGlass: Whether to enable glass effect mode
	static func configurePopoverForGlassEffect(_ popover: NSPopover, enableGlass: Bool) {
		if enableGlass {
			popover.behavior = .transient
			popover.animates = true
			
			// Access the popover's window and configure it
			DispatchQueue.main.async {
				if let popoverWindow = popover.contentViewController?.view.window {
					popoverWindow.isOpaque = false
					popoverWindow.backgroundColor = .clear
					
					if let contentView = popoverWindow.contentView {
						contentView.wantsLayer = true
						contentView.layer?.backgroundColor = .clear
					}
				}
			}
		}
	}
}

/// SwiftUI view modifier to configure window for glass effects
struct WindowGlassConfiguration: ViewModifier {
	let enableGlass: Bool
	
	func body(content: Content) -> some View {
		content
			.onAppear {
				configureCurrentWindow()
			}
			.onChange(of: enableGlass) { _, newValue in
				configureCurrentWindow()
			}
	}
	
	private func configureCurrentWindow() {
		DispatchQueue.main.async {
			// Find the key window or the first window
			if let window = NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first {
				WindowConfigurator.configureForGlassEffect(window, enableGlass: enableGlass)
			}
		}
	}
}

extension View {
	/// Configures the window to support glass effects
	/// - Parameter enableGlass: Whether glass effect should be enabled
	func configureWindowForGlass(_ enableGlass: Bool) -> some View {
		modifier(WindowGlassConfiguration(enableGlass: enableGlass))
	}
}
