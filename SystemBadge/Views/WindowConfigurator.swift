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
            // Make window semi-opaque for glass effect readability
            let opacityValue = UserDefaults.standard.object(forKey: "glassOpacity") as? Double ?? 85.0
            let normalizedOpacity = max(0.0, min(1.0, opacityValue / 100.0))
            let glassBackgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(CGFloat(normalizedOpacity))
            window.isOpaque = false
            window.backgroundColor = glassBackgroundColor
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
			
			// Configure the window's content view for visual effects
            if let contentView = window.contentView {
                contentView.wantsLayer = true
                contentView.layer?.backgroundColor = glassBackgroundColor.cgColor
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
                    let opacityValue = UserDefaults.standard.object(forKey: "glassOpacity") as? Double ?? 85.0
                    let normalizedOpacity = max(0.0, min(1.0, opacityValue / 100.0))
                    let glassBackgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(CGFloat(normalizedOpacity))
                    popoverWindow.isOpaque = false
                    popoverWindow.backgroundColor = glassBackgroundColor

                    if let contentView = popoverWindow.contentView {
                        contentView.wantsLayer = true
                        contentView.layer?.backgroundColor = glassBackgroundColor.cgColor
                    }
                }
            }
        }
    }
}

/// SwiftUI view modifier to configure window for glass effects
struct WindowGlassConfiguration: ViewModifier {
    let enableGlass: Bool
    @AppStorage("glassOpacity") private var glassOpacity = 85.0
	
	func body(content: Content) -> some View {
        content
            .onAppear {
                configureCurrentWindow()
            }
            .onChange(of: enableGlass) { _, newValue in
                configureCurrentWindow()
            }
            .onChange(of: glassOpacity) { _, newValue in
                configureCurrentWindow()
            }
    }
	
    private func configureCurrentWindow() {
        DispatchQueue.main.async {
            let windows = NSApplication.shared.windows
            for window in windows {
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
