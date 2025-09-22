//
//  BatteryInfo.swift
//  SystemBadge
//
//  Created by Richard Michaud on 9/21/25.
//

import Foundation
import IOKit.ps

func getBatteryHealth() -> String? {
    // Obtain a blob that contains power source info
    guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
        return nil
    }

    // Get a list of power sources
    guard let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else {
        return nil
    }

    for ps in list {
        // For each power source, get its description dictionary
        guard let description = IOPSGetPowerSourceDescription(blob, ps)?.takeUnretainedValue() as? [String: Any] else {
            continue
        }

        // Battery health is available as kIOPSBatteryHealthKey when supported
        if let health = description[kIOPSBatteryHealthKey as String] as? String {
            return health
        }
    }

    return nil
}


func getBatteryPercentageHealth() -> Double? {
    // Obtain a blob that contains power source info
    guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
        return nil
    }

    // Get a list of power sources
    guard let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else {
        return nil
    }

    for ps in list {
        // For each power source, get its description dictionary
        guard let description = IOPSGetPowerSourceDescription(blob, ps)?.takeUnretainedValue() as? [String: Any] else {
            continue
        }

        // Extract current and max capacity to compute percentage
        if let maxCapacity = description[kIOPSMaxCapacityKey as String] as? Int,
           let currentCapacity = description[kIOPSCurrentCapacityKey as String] as? Int,
           maxCapacity > 0 {
            return (Double(currentCapacity) / Double(maxCapacity)) * 100.0
        }
    }

    return nil
}

