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
	
	func makeNSView(context: Context) -> NSVisualEffectView {
		let effectView = NSVisualEffectView()
		effectView.material = .hudWindow
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
		nsView.layer?.cornerRadius = cornerRadius
		
		// Update tint color
		if let colorLayer = nsView.layer?.sublayers?.first(where: { $0 is CALayer && $0.backgroundColor != nil }) {
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
