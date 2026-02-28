//
//  StatusEntryView.swift
//  SystemBadge
//
//  Created by Richard Michaud on 1/30/22.
//

import SwiftUI
//import BatteryBarView


struct StatusEntryView: View {
	let name: String
	let value: String
	let icon: Image
	@AppStorage("metricColor") private var customMetricColor = Color("MetricColor")
	@AppStorage("labelColor") private var customLabelColor = Color("LabelColor")
	@AppStorage("useSystemColors") private var useSystemColors = true
	@AppStorage("enableLiquidGlass") private var enableLiquidGlass = true
	@Environment(\.colorScheme) private var colorScheme
	
	// Dynamic colors based on theme settings
    private var metricColor: Color {
        if useSystemColors {
            return colorScheme == .dark ? .primary : .primary
        }
        return customMetricColor
    }
	
    private var labelColor: Color {
        if useSystemColors {
            return colorScheme == .dark ? .secondary : .secondary
        }
        return customLabelColor
    }
	
    var body: some View {
		HStack {
			icon
				.frame(width: 35.0, height: 35.0, alignment: .leading)
				.font(.title)
				.foregroundColor(.yellow)
			Text(name)
				.font(.body)
				.foregroundColor(labelColor)
				.bold()
				.frame(width: 250.0, alignment: .trailing)
			Divider()
			if name == "Battery Percentage", let pct = Self.percentValue(from: value) {
				BatteryBarView(
					percentage: pct,
					fontName: "EnhancedDotDigital-7",
					fontSize: 18,
					barForeground: metricColor,
					barBackground: labelColor,
					inverseLabelColor: labelColor
				)
				.frame(width: 400.0, height: 24, alignment: .leading)
				.clipped()
				.frame(width: 450.0, alignment: .leading)
			} else {
				Text(value)
					.font(.custom("EnhancedDotDigital-7", size: 18))
					.foregroundColor(metricColor)
					.bold()
					.italic()
					.frame(width: 450.0, alignment: .leading)
			}
		}
        
    }
	
	static func percentValue(from text: String) -> Double? {
		let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
		guard let num = trimmed.split(separator: "%").first, let pct = Double(num) else {
			return nil
		}
		return pct
	}
}

struct StatusEntryView_Previews: PreviewProvider {
    static var previews: some View {
		VStack {
			StatusEntryView(name: "CPU", value: "Intel(R) Core(TM) i9-9980HK CPU @ 2.40GHz", icon: Image(systemName: "cpu"))
			StatusEntryView(name: "IP Address", value: "192.168.135.192", icon: Image(systemName: "network"))
		}
	}
}
