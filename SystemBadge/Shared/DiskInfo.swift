//
//  DiskInfo.swift
//  SystemBadge
//
//  Created by Richard Michaud on 9/21/25.
//

import Foundation

func getDiskSpaceInfo(for path: URL, silent: Bool = false) -> (totalCapacity: String, usedCapacity: String, availableCapacity: String) {
	var totalCapacity = "n/a"
	var usedCapacity = "n/a"
	var availableCapacity = "n/a"
	
	// Validate that the path exists before querying
	guard FileManager.default.fileExists(atPath: path.path) else {
		if !silent {
			print("Path does not exist: \(path.path)")
		}
		return (totalCapacity, usedCapacity, availableCapacity)
	}

	do {
		// Try using volumeAvailableCapacityKey first (doesn't trigger CacheDelete)
		// Fall back to volumeAvailableCapacityForImportantUsageKey if needed
		let resourceValues = try path.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])

		guard let totalCapacityInt = resourceValues.volumeTotalCapacity,
			  let availableCapacityInt64 = resourceValues.volumeAvailableCapacity else {
			if !silent {
				print("Could not retrieve disk space information for \(path.path)")
			}
			return (totalCapacity, usedCapacity, availableCapacity)
		}
		let total = Int64(totalCapacityInt)
		let available = Int64(availableCapacityInt64)
		let used = total - available
		let formatter = ByteCountFormatter()
		formatter.countStyle = .file
		
		totalCapacity = formatter.string(fromByteCount: total)
		availableCapacity = formatter.string(fromByteCount: available)
		usedCapacity = formatter.string(fromByteCount: used)

		return (totalCapacity, usedCapacity, availableCapacity)
	} catch {
		if !silent {
			print("Error retrieving disk space information: \(error.localizedDescription)")
		}
		return (totalCapacity, usedCapacity, availableCapacity)
	}
}
