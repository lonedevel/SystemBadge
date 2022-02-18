//
//  TextViews.swift
//  SystemBadge
//
//  Created by Richard Michaud on 1/30/22.
//

import SwiftUI

struct TitleText: View {
	let text: String
	
	var body: some View {
		Text(text)
			.font(.largeTitle)
			.kerning(2.0)
			.fontWeight(.black)
//			.foregroundColor(Color("TextColor"))
	}
}

struct TextViews_Previews: PreviewProvider {
    static var previews: some View {
		TitleText(text: "This is a test!")
    }
}
