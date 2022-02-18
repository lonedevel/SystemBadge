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
	
    var body: some View {
		HStack {
			icon
				.frame(width: 35.0, height: 35.0)
//				.opacity(0.4)
				.foregroundColor(.blue)
			Text(name)
				.font(.body)
				.foregroundColor(Color.teal)
				.bold()
				.frame(width: 180.0, alignment: .center)
				.background(
					Capsule()
						.fill(.black)
						
				)
			Text(value)
				.font(Font.custom("Enhanced Dot Digital-7", size: 18))
				.foregroundColor(.green)
//				.bold()
				.frame(width: 400.0, alignment: .leading)
//				.background(
//					Rectangle()
//						.fill(.gray)
//				)
//
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
