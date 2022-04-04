//
//  SystemBadgeApp.swift
//  SystemBadge
//
//  Created by Richard Michaud on 2/1/22.
//

import SwiftUI

@main
struct SystemBadgeApp: App {
	@AppStorage("showCpu") private var showCpu = true
	@AppStorage("showPublicInternet") private var showPublicInternet = true
	@AppStorage("metricColor") private var metricColor = Color("MetricColor")
	
	var badgeInfo = BadgeInfo()

	@NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        WindowGroup {
			ContentView(badge: badgeInfo)
        }
		Settings {
			PreferencesView()
		}
    }
}

extension Color: RawRepresentable {

	public init?(rawValue: String) {
		
		guard let data = Data(base64Encoded: rawValue) else{
			self = .black
			return
		}
		
		do{
			let color = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? NSColor ?? .black
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

