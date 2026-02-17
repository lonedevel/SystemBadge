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
	var material: NSVisualEffectView.Material = .underWindowBackground
	
	func makeNSView(context: Context) -> NSVisualEffectView {
		let effectView = NSVisualEffectView()
		
		// Use the specified material for blur effect
		effectView.material = material
		
		// CRITICAL: Use behindWindow to blur content BEHIND the window (desktop, etc.)
		effectView.blendingMode = .behindWindow
		
		effectView.state = .active
		effectView.wantsLayer = true
		effectView.layer?.cornerRadius = cornerRadius
		
		// Apply tint color if provided
		if let tintColor = tintColor {
			let colorLayer = CALayer()
			colorLayer.backgroundColor = tintColor.withAlphaComponent(0.3).cgColor
			effectView.layer?.addSublayer(colorLayer)
			colorLayer.frame = effectView.bounds
			colorLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
		}
		
		return effectView
	}
	
	func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
		nsView.material = material
		nsView.layer?.cornerRadius = cornerRadius
		
		// Update tint color
		if let colorLayer = nsView.layer?.sublayers?.first(where: { $0.backgroundColor != nil }) {
			if let tintColor = tintColor {
				colorLayer.backgroundColor = tintColor.withAlphaComponent(0.3).cgColor
			} else {
				colorLayer.removeFromSuperlayer()
			}
		} else if let tintColor = tintColor {
			let colorLayer = CALayer()
			colorLayer.backgroundColor = tintColor.withAlphaComponent(0.3).cgColor
			colorLayer.frame = nsView.bounds
			colorLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
			nsView.layer?.addSublayer(colorLayer)
		}
	}
}
