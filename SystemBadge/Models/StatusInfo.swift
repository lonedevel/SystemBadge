//
//  StatusInfo.swift
//  SystemBadge
//
//  Created by Richard Michaud on 1/29/22.
//

import Foundation
import SystemConfiguration
import SwiftUI


func bashCmd(cmd: String) -> String {
	return execCommand(command: "bash", args: ["-c", cmd])
}

//func zshCmd(cmd: String) -> String {
//	return execCommand(command: "zsh", args: ["-c", cmd])
//}

func execCommand(command: String, args: [String]) -> String {
	if !command.hasPrefix("/") {
		let commandFull = execCommand(command: "/usr/bin/which", args: [command]).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
		return execCommand(command: commandFull, args: args)
	} else {
		let proc = Process()
		proc.launchPath = command
		proc.arguments = args
		let pipe = Pipe()
		proc.standardOutput = pipe
		proc.launch()
		let data = pipe.fileHandleForReading.readDataToEndOfFile()
		return String(data: data, encoding: String.Encoding.utf8)!
	}
}

struct StatusEntry {
	let name: String
	var commandValue: () -> String
	let icon: Image
}

class StatusInfo: ObservableObject {
	@Published var statusEntries: [StatusEntry] = []
	init() {
		self.refresh()
	}
	
	func refresh() {
		//Host.current().localizedName
		statusEntries.append(StatusEntry(
			name: "Short Hostname",
			commandValue: { ()-> String in
				return Host.current().localizedName!
					.trimmingCharacters(in: .whitespacesAndNewlines)
			},
			icon: Image(systemName: "desktopcomputer.and.arrow.down")
		))
		
		statusEntries.append(StatusEntry(
			name: "FQDN Hostname",
			commandValue: { ()-> String in
				let command = "hostname -f"
				return bashCmd(cmd: command)
					.trimmingCharacters(in: .whitespacesAndNewlines)
			},
			icon: Image(systemName: "desktopcomputer.and.arrow.down")
		))

		
		statusEntries.append(StatusEntry(
			name: "Username",
			commandValue: { ()-> String in
				return "\(NSUserName()) ( \(NSFullUserName()) )"
					.trimmingCharacters(in: .whitespacesAndNewlines)
 			},
			icon: Image(systemName: "person")
		))
		
		// Loop through each network interface and extract the BSD and localized name then gather its IPv4 IP Address
		for interface in SCNetworkInterfaceCopyAll() as NSArray {
			if let name = SCNetworkInterfaceGetBSDName(interface as! SCNetworkInterface),
//			   let type = SCNetworkInterfaceGetInterfaceType(interface as! SCNetworkInterface),
			   let localizedName = SCNetworkInterfaceGetLocalizedDisplayName(interface as! SCNetworkInterface){
				let command = "ifconfig \(name) | grep inet | grep -v inet6 | cut -d' ' -f2 | tail -n1"  // This works
//				let command = "ipconfig getifaddr \(name)"  // This does not work
				let ip_addr = bashCmd(cmd: command)
				
				let iconName = (localizedName as String == "Wi-Fi") ? "wifi": "network"
				
				if ip_addr != "" {
					statusEntries.append(StatusEntry(name: "\(localizedName) (\(name))",
													 commandValue: { ()-> String in return "\(ip_addr)"
																	.trimmingCharacters(in: .whitespacesAndNewlines)
																   },
													 icon: Image(systemName: iconName )
													))
				}
			}
		}
		
//		statusEntries.append(StatusEntry(
//			name: "IP Address",
//			commandValue: { ()-> String in
//				let command = "ifconfig | grep inet | grep -v inet6 | cut -d' ' -f2 | tail -n1"
//				return bashCmd(cmd: command)
//					.trimmingCharacters(in: .whitespacesAndNewlines)
//			},
//			icon: Image(systemName: "network")
//		))
//
			
		statusEntries.append(StatusEntry(
			name: "Public IP Address",
			commandValue: { ()-> String in
				let command = "curl --silent ipecho.net/plain ; echo"
				return bashCmd(cmd: command)
					.trimmingCharacters(in: .whitespacesAndNewlines)
			},
			icon: Image(systemName: "network")
		))
		
//		if (showCpu) {
			statusEntries.append(StatusEntry(
				name: "CPU Type",
				commandValue: { ()-> String in
					let command = "sysctl -n machdep.cpu.brand_string |awk '$1=$1' | sed 's/([A-Z]{1,2})//g'"
					return bashCmd(cmd: command)
						.trimmingCharacters(in: .whitespacesAndNewlines)
				},
				icon: Image(systemName: "cpu")
			))
		
			statusEntries.append(StatusEntry(
				name: "CPU cores/threads",
				commandValue: { ()-> String in
					let command = "echo `sysctl -n hw.physicalcpu` '/' `sysctl -n hw.logicalcpu`"
					return bashCmd(cmd: command)
						.trimmingCharacters(in: .whitespacesAndNewlines)
				},
				icon: Image(systemName: "cpu")
			))
//	 	}
		
		//"$(( $(sysctl -n hw.memsize) / 1024 ** 3  )) GB"
		statusEntries.append(StatusEntry(
			name: "RAM",
			commandValue: { ()-> String in
				let command = "expr `sysctl -n hw.memsize` / 1073741824"
				let result = "\(bashCmd(cmd: command).trimmingCharacters(in: .whitespacesAndNewlines)) GB"
				return result
			},
			icon: Image(systemName: "memorychip")
		))
		
		statusEntries.append(StatusEntry(
			name: "Operating System",
			commandValue: { ()-> String in
				let command = "echo `sw_vers -productName` `sw_vers -productVersion`"
				return bashCmd(cmd: command)
					.trimmingCharacters(in: .whitespacesAndNewlines)
			},
			icon: Image(systemName: "macwindow.on.rectangle")
		))
		
		statusEntries.append(StatusEntry(
			name: "System Uptime",
			commandValue: { ()-> String in
				return ProcessInfo.processInfo.systemUptime.stringFromTimeInterval()
					.trimmingCharacters(in: .whitespacesAndNewlines)
			},
			icon: Image(systemName: "deskclock")
		))
	}
}

extension TimeInterval {
	func stringFromTimeInterval() -> String {

		let time = NSInteger(self)
		let seconds = time % 60
		let minutes = (time / 60) % 60
		let hours = (time / 3600) % 24
		let days = (time / 84000)

		return String(format: "%02d d %0.2d h %0.2d m %0.2d s",days,hours,minutes,seconds)
	}
}
