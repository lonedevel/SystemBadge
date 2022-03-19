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
