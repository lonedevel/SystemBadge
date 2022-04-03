import Foundation
import SystemConfiguration

for interface in SCNetworkInterfaceCopyAll() as NSArray {
	if let name = SCNetworkInterfaceGetBSDName(interface as! SCNetworkInterface),
	   let type = SCNetworkInterfaceGetInterfaceType(interface as! SCNetworkInterface),
	   let localizedName = SCNetworkInterfaceGetLocalizedDisplayName(interface as! SCNetworkInterface){
			print("Interface \(name) is of type \(type) named \(localizedName)")
	}
}

//func printAddresses() {
//	var addrList : UnsafeMutablePointer<ifaddrs>?
//	guard
//		getifaddrs(&addrList) == 0,
//		let firstAddr = addrList
//	else { return }
//	defer { freeifaddrs(addrList) }
//	for cursor in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
//		let interfaceName = String(cString: cursor.pointee.ifa_name)
//		let addrStr: String
//		var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
//		if
//			let addr = cursor.pointee.ifa_addr,
//			getnameinfo(addr, socklen_t(addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST) == 0,
//			hostname[0] != 0
//		{
//			addrStr = String(cString: hostname)
//		} else {
//			addrStr = "?"
//		}
//		print(interfaceName, addrStr)
//	}
//	return
//}
//
//printAddresses()


func getIfAddr(iName:String)-> String {
	var addrList : UnsafeMutablePointer<ifaddrs>?
	guard
		getifaddrs(&addrList) == 0,
		let firstAddr = addrList
	else { return "?"}
	defer { freeifaddrs(addrList) }
	for cursor in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
		let interfaceName = String(cString: cursor.pointee.ifa_name)
		let addrStr: String
		var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
		if
			let addr = cursor.pointee.ifa_addr,
			getnameinfo(addr, socklen_t(addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST) == 0,
			hostname[0] != 0
		{
			addrStr = String(cString: hostname)
		} else {
			addrStr = "?"
		}
		if interfaceName == iName {
			return(addrStr)
		}
		//print(interfaceName, addrStr)
	}
	return "?"
}
print(getIfAddr(iName: "en0"))



import Foundation
import IOKit.ps
import Darwin

enum BatteryError: Error { case error }

do {
	// Take a snapshot of all the power source info
	guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue()
		else { throw BatteryError.error }

	// Pull out a list of power sources
	guard let sources: NSArray = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue()
		else { throw BatteryError.error }

	// For each power source...
	for ps in sources {
		// Fetch the information for a given power source out of our snapshot
		guard let info: NSDictionary = IOPSGetPowerSourceDescription(snapshot, ps as CFTypeRef)?.takeUnretainedValue()
			else { throw BatteryError.error }

		// Pull out the name and current capacity
		print(info)
		
		if let name = info[kIOPSNameKey] as? String,
			let capacity = info[kIOPSCurrentCapacityKey] as? Int,
			let max = info[kIOPSMaxCapacityKey] as? Int {
			print("\(name): \(capacity) of \(max)")
		}
	}
} catch {
	fatalError()
}


