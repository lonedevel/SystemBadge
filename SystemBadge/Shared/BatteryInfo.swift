//
//  BatteryInfo.swift
//  SystemBadge
//
//  Created by Richard Michaud on 9/21/25.
//

import Foundation
import IOKit.ps

// MARK: - Private Helper

/// Retrieves power source descriptions from IOKit
/// - Returns: Array of power source description dictionaries, or nil if unavailable
private func getPowerSourceDescriptions() -> [[String: Any]]? {
    // Copy rule - IOPSCopyPowerSourcesInfo has "Copy" in its name, so it follows the Create Rule
    // This means ownership is transferred to us, and we must use takeRetainedValue()
    guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
        return nil
    }
    
    // Copy rule - IOPSCopyPowerSourcesList also has "Copy" in its name
    // Ownership is transferred, so we use takeRetainedValue()
    guard let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else {
        return nil
    }
    
    return list.compactMap { ps in
        // Get rule - IOPSGetPowerSourceDescription has "Get" in its name, so it follows the Get Rule
        // This means we're just borrowing the reference, not taking ownership
        // We must use takeUnretainedValue() here to avoid memory management issues
        IOPSGetPowerSourceDescription(blob, ps)?.takeUnretainedValue() as? [String: Any]
    }
}

// MARK: - Public API

func getBatteryHealth() -> String? {
    guard let descriptions = getPowerSourceDescriptions() else {
        return nil
    }
    
    for description in descriptions {
        // Battery health is available as kIOPSBatteryHealthKey when supported
        if let health = description[kIOPSBatteryHealthKey as String] as? String {
            return health
        }
    }
    
    return nil
}

func getBatteryPercentageHealth() -> Double? {
    guard let descriptions = getPowerSourceDescriptions() else {
        return nil
    }
    
    for description in descriptions {
        // Extract current and max capacity to compute percentage
        if let maxCapacity = description[kIOPSMaxCapacityKey as String] as? Int,
           let currentCapacity = description[kIOPSCurrentCapacityKey as String] as? Int,
           maxCapacity > 0 {
            return (Double(currentCapacity) / Double(maxCapacity)) * 100.0
        }
    }
    
    return nil
}

