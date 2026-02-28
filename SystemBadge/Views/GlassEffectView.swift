//
//  GlassEffectView.swift
//  SystemBadge
//
//  Created by Richard Michaud
//

import SwiftUI
import AppKit

/// SwiftUI wrapper for NSVisualEffectView to create glass effects
struct GlassEffectView: NSViewRepresentable {
	var cornerRadius: CGFloat = 16.0
	var tintColor: NSColor?
	var material: NSVisualEffectView.Material = .contentBackground  // Match main window
	var blendingMode: NSVisualEffectView.BlendingMode = .withinWindow  // Match main window
	var opacity: CGFloat = 0.85  // Added opacity control for better visibility
	
	func makeNSView(context: Context) -> NSVisualEffectView {
		let effectView = NSVisualEffectView()
		
		// Use the specified material for blur effect
		effectView.material = material
		
		// Use specified blending mode (behindWindow blurs desktop, withinWindow blurs content)
		effectView.blendingMode = blendingMode
		
		effectView.state = .active
		effectView.wantsLayer = true
		effectView.layer?.cornerRadius = cornerRadius
		
		// Apply tint color with adjustable opacity
		if let tintColor = tintColor {
			let colorLayer = CALayer()
			colorLayer.backgroundColor = tintColor.withAlphaComponent(opacity * 0.5).cgColor
			effectView.layer?.addSublayer(colorLayer)
			colorLayer.frame = effectView.bounds
			colorLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
		} else {
			// Add a subtle white/gray overlay for better readability
			let overlayLayer = CALayer()
			overlayLayer.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(opacity * 0.3).cgColor
			effectView.layer?.addSublayer(overlayLayer)
			overlayLayer.frame = effectView.bounds
			overlayLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
		}
		
		return effectView
	}
	
	func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
		nsView.material = material
		nsView.blendingMode = blendingMode
		nsView.layer?.cornerRadius = cornerRadius
		
		// Remove existing color layers
		nsView.layer?.sublayers?.filter { $0.backgroundColor != nil }.forEach { $0.removeFromSuperlayer() }
		
		// Apply updated tint color
		if let tintColor = tintColor {
			let colorLayer = CALayer()
			colorLayer.backgroundColor = tintColor.withAlphaComponent(opacity * 0.5).cgColor
			colorLayer.frame = nsView.bounds
			colorLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
			nsView.layer?.addSublayer(colorLayer)
		} else {
			// Add a subtle overlay for better readability
			let overlayLayer = CALayer()
			overlayLayer.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(opacity * 0.3).cgColor
			overlayLayer.frame = nsView.bounds
			overlayLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
			nsView.layer?.addSublayer(overlayLayer)
		}
	}
}
