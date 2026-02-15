//
//  DiskInfo.swift
//  SystemBadge
//
//  Created by Richard Michaud on 9/21/25.
//

import Foundation

func getDiskSpaceInfo(for path: URL)-> (totalCapacity: String, usedCapacity: String, availableCapacity:String) {
	var totalCapacity = "n/a"
	var usedCapacity = "n/a"
	var availableCapacity = "n/a"
	
	// Validate that the path exists before querying
	guard FileManager.default.fileExists(atPath: path.path) else {
		print("Path does not exist: \(path.path)")
		return (totalCapacity, usedCapacity, availableCapacity)
	}

	do {
		let resourceValues = try path.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey])

		guard let totalCapacityInt = resourceValues.volumeTotalCapacity,
			  let availableCapacityInt64 = resourceValues.volumeAvailableCapacityForImportantUsage else {
			print("Could not retrieve disk space information for \(path.path)")
			return (totalCapacity, usedCapacity, availableCapacity)
		}
		let total = Int64(totalCapacityInt)
		let available = availableCapacityInt64
		let used = total - available
		let formatter = ByteCountFormatter()
		formatter.countStyle = .file
		
		totalCapacity = formatter.string(fromByteCount: total)
		availableCapacity = formatter.string(fromByteCount: available)
		usedCapacity = formatter.string(fromByteCount: used)

		return (totalCapacity, usedCapacity, availableCapacity)
	} catch {
		print("Error retrieving disk space information: \(error.localizedDescription)")
		return (totalCapacity, usedCapacity, availableCapacity)
	}
}
