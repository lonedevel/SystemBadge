//
//  ThemeManager.swift
//  SystemBadge
//
//  Created for enhanced theming and Liquid Glass support
//

import SwiftUI
import AppKit

/// Manages theme colors that adapt to light/dark mode
struct ThemeManager {
    @AppStorage("useSystemColors") private var useSystemColors = true
    @AppStorage("enableLiquidGlass") private var enableLiquidGlass = true
    @AppStorage("metricColor") private var customMetricColor = Color("MetricColor")
    @AppStorage("labelColor") private var customLabelColor = Color("LabelColor")
    
    let colorScheme: ColorScheme
    
    /// Dynamic metric color based on theme settings
    var metricColor: Color {
        if useSystemColors {
            return colorScheme == .dark ? Color.primary : Color.primary
        }
        return customMetricColor
    }
    
    /// Dynamic label color based on theme settings
    var labelColor: Color {
        if useSystemColors {
            return colorScheme == .dark ? Color.secondary : Color.secondary
        }
        return customLabelColor
    }
    
    /// Returns appropriate colors for the current theme
    static func colors(for colorScheme: ColorScheme, useSystem: Bool, enableGlass: Bool) -> (metric: Color, label: Color) {
        if useSystem {
            return (
                metric: colorScheme == .dark ? .primary : .primary,
                label: colorScheme == .dark ? .secondary : .secondary
            )
        }
        
        // Return stored custom colors
        return (
            metric: Color("MetricColor"),
            label: Color("LabelColor")
        )
    }
}

/// Environment key for theme manager
struct ThemeManagerKey: EnvironmentKey {
    static let defaultValue = ThemeManager(colorScheme: .light)
}

extension EnvironmentValues {
    var themeManager: ThemeManager {
        get { self[ThemeManagerKey.self] }
        set { self[ThemeManagerKey.self] = newValue }
    }
}

extension View {
    /// Injects theme manager into the environment
    func withThemeManager(colorScheme: ColorScheme) -> some View {
        environment(\.themeManager, ThemeManager(colorScheme: colorScheme))
    }
}
