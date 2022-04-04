//
//  StatusEntryView.swift
//  SystemBadge
//
//  Created by Richard Michaud on 1/30/22.
//

import SwiftUI


struct StatusEntryView: View {
	let name: String
	let value: String
	let icon: Image
	@AppStorage("metricColor") private var metricColor = Color("MetricColor")
	@AppStorage("labelColor") private var labelColor = Color("LabelColor")
	
    var body: some View {
		HStack {
			icon
				.frame(width: 35.0, height: 35.0, alignment: .leading)
				.font(.title)
				.foregroundColor(.yellow)
			Text(name)
				.font(.body)
				.foregroundColor($labelColor.wrappedValue)
				.bold()
				.frame(width: 220.0, alignment: .trailing)
			Divider()
			Text(value)
				.font(.custom("EnhancedDotDigital-7", size: 18))
//				.foregroundColor(Color("MetricColor"))
				.foregroundColor($metricColor.wrappedValue)
				.bold()
				.italic()
				.frame(width: 450.0, alignment: .leading)
		}
        
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
