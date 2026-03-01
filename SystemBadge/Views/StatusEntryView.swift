//
//  StatusEntryView.swift
//  SystemBadge
//
//  Created by Richard Michaud on 1/30/22.
//

import SwiftUI
//import BatteryBarView


struct StatusEntryView: View {
    let entry: StatusEntry
    @AppStorage("metricColor") private var customMetricColor = Color("MetricColor")
    @AppStorage("labelColor") private var customLabelColor = Color("LabelColor")
    @AppStorage("useSystemColors") private var useSystemColors = true
    @AppStorage("enableLiquidGlass") private var enableLiquidGlass = true
    @AppStorage("useCustomColorsWithGlass") private var useCustomColorsWithGlass = true
    @Environment(\.colorScheme) private var colorScheme
	
	// Dynamic colors based on theme settings
    private var metricColor: Color {
        if useSystemColors || (enableLiquidGlass && !useCustomColorsWithGlass) {
            return colorScheme == .dark ? .primary : .primary
        }
        return customMetricColor
    }
	
    private var labelColor: Color {
        if useSystemColors || (enableLiquidGlass && !useCustomColorsWithGlass) {
            return colorScheme == .dark ? .secondary : .secondary
        }
        return customLabelColor
    }
	
    var body: some View {
        HStack {
            entry.icon
                .frame(width: 35.0, height: 35.0, alignment: .leading)
                .font(.title)
                .foregroundColor(.yellow)
            Text(entry.name)
                .font(.body)
                .foregroundColor(labelColor)
                .bold()
                .frame(width: 250.0, alignment: .trailing)
            Divider()
            if entry.name == "Battery Percentage", let pct = Self.percentValue(from: entry.value) {
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
                metricView
                    .frame(width: 450.0, alignment: .leading)
            }
        }
        
    }

    @ViewBuilder
    private var metricView: some View {
        switch entry.displayStyle {
        case .text:
            Text(entry.value)
                .font(.custom("EnhancedDotDigital-7", size: 18))
                .foregroundColor(metricColor)
                .bold()
                .italic()
        case .percentBar:
            if let pct = entry.primaryValue ?? Self.percentValue(from: entry.value) {
                PercentBarView(
                    percentage: pct,
                    fontName: "EnhancedDotDigital-7",
                    fontSize: 18,
                    barForeground: metricColor,
                    barBackground: labelColor
                )
                .frame(height: 24)
            } else {
                Text(entry.value)
                    .font(.custom("EnhancedDotDigital-7", size: 18))
                    .foregroundColor(metricColor)
                    .bold()
                    .italic()
            }
        case .ratePair:
            RatePairView(
                downValue: entry.primaryValue ?? 0,
                upValue: entry.secondaryValue ?? 0,
                unit: entry.unit ?? "",
                metricColor: metricColor,
                labelColor: labelColor
            )
        case .sparkline:
            SparklineMetricView(
                valueText: entry.value,
                history: entry.history,
                lineColor: metricColor,
                labelColor: labelColor,
                unit: entry.unit ?? "",
                scaleOverride: entry.scaleMode
            )
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
            StatusEntryView(entry: StatusEntry(
                id: 0,
                name: "CPU",
                category: "System",
                cadence: .slow,
                displayStyle: .text,
                unit: nil,
                scaleMode: nil,
                commandValue: { MetricSample.text("Intel(R) Core(TM) i9-9980HK CPU @ 2.40GHz") },
                icon: Image(systemName: "cpu"),
                value: "Intel(R) Core(TM) i9-9980HK CPU @ 2.40GHz"
            ))
            StatusEntryView(entry: StatusEntry(
                id: 1,
                name: "Network Throughput",
                category: "Performance",
                cadence: .fast,
                displayStyle: .ratePair,
                unit: "MB/s",
                scaleMode: nil,
                commandValue: { MetricSample(text: "↓ 12.3 MB/s  ↑ 1.2 MB/s", primary: 12.3, secondary: 1.2) },
                icon: Image(systemName: "arrow.up.arrow.down"),
                value: "↓ 12.3 MB/s  ↑ 1.2 MB/s",
                primaryValue: 12.3,
                secondaryValue: 1.2
            ))
        }
    }
}
