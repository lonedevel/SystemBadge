//
//  SystemBadgeApp.swift
//  SystemBadge
//
//  Created by Richard Michaud on 2/1/22.
//

import SwiftUI

/// Helper view to access and configure the window with glass effect
struct WindowAccessor: NSViewRepresentable {
	let enableGlass: Bool
	
	func makeNSView(context: Context) -> NSView {
		let view = NSView()
		view.wantsLayer = true
		view.layer?.backgroundColor = .clear
		
		DispatchQueue.main.async {
			configureWindow(for: view)
		}
		return view
	}
	
	func updateNSView(_ nsView: NSView, context: Context) {
		DispatchQueue.main.async {
			configureWindow(for: nsView)
		}
	}
	
	private func configureWindow(for view: NSView) {
		guard let window = view.window else { return }
		
        if enableGlass {
            // Make window semi-opaque for better readability
            let glassBackgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.7)
            window.isOpaque = false
            window.backgroundColor = glassBackgroundColor
			window.hasShadow = true
			
			// Full-size content view to extend to entire window including tab bar
			window.titlebarAppearsTransparent = true
			window.styleMask.insert(.fullSizeContentView)
			window.titleVisibility = .hidden
			
			// Allow the window to be key
			window.isMovableByWindowBackground = true
			
			// Get the root content view
			guard let contentView = window.contentView else { return }
			
            // Make the content view container semi-opaque to match the window
            contentView.wantsLayer = true
            contentView.layer?.backgroundColor = glassBackgroundColor.cgColor
			
			// Check if we already have a visual effect view
			let hasEffectView = contentView.subviews.first(where: { $0 is NSVisualEffectView }) != nil
			
			if !hasEffectView {
				// Create visual effect view
				let visualEffectView = NSVisualEffectView()
				
				// Try .menu material - it often provides the best blur for floating windows
				visualEffectView.material = .contentBackground
				visualEffectView.blendingMode = .withinWindow
				visualEffectView.state = .active
				visualEffectView.wantsLayer = true
				
				// Critical: Set frame and autoresizing
				visualEffectView.frame = contentView.bounds
				visualEffectView.autoresizingMask = [.width, .height]
				
				// Insert at index 0 (bottom of view hierarchy)
				contentView.addSubview(visualEffectView, positioned: .below, relativeTo: contentView.subviews.first)
				
				// Make all other subviews have clear backgrounds
				for subview in contentView.subviews where subview !== visualEffectView {
					makeViewTransparent(subview)
				}
			}
		} else {
			// Restore default appearance
			window.isOpaque = true
			window.backgroundColor = NSColor.windowBackgroundColor
			window.titlebarAppearsTransparent = false
			window.styleMask.remove(.fullSizeContentView)
			window.titleVisibility = .visible
			
			// Remove visual effect views
			window.contentView?.subviews
				.filter { $0 is NSVisualEffectView }
				.forEach { $0.removeFromSuperview() }
			
			// Restore content view background
			window.contentView?.layer?.backgroundColor = nil
		}
	}
	
	private func makeViewTransparent(_ view: NSView) {
		view.wantsLayer = true
		view.layer?.backgroundColor = .clear
		
		// Recursively make child views transparent too
		for subview in view.subviews {
			makeViewTransparent(subview)
		}
	}
}

@available(macOS 26.0, *)
@main
struct SystemBadgeApp: App {
	@AppStorage("showCpu") private var showCpu = true
	@AppStorage("showPublicInternet") private var showPublicInternet = true
	@AppStorage("metricColor") private var metricColor = Color("MetricColor")
	@AppStorage("enableLiquidGlass") private var enableLiquidGlass = true
	
	var badgeInfo = BadgeInfo()

	@NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        WindowGroup {
			ContentView(badge: badgeInfo)
				.configureWindowForGlass(enableLiquidGlass)
        }
		.windowLevel(.floating)
		Settings {
			PreferencesView()
		}
    }
}

extension Color: @retroactive RawRepresentable {

	public init?(rawValue: String) {
		
		guard let data = Data(base64Encoded: rawValue) else{
			self = .black
			return
		}
		
		do{
			let color = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) ?? .black
			self = Color(color)
		}catch{
			self = .black
		}
		
	}

	public var rawValue: String {
		
		do{
			let data = try NSKeyedArchiver.archivedData(withRootObject: NSColor(self), requiringSecureCoding: false) as Data
			return data.base64EncodedString()
			
		}catch{
			
			return ""
			
		}
		
	}

}
