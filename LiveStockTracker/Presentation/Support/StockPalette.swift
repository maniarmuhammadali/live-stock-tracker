//
//  StockPalette.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import SwiftUI
import UIKit

struct StockPalette: Equatable, Sendable {
    let screenBackground: Color
    let groupedSurface: Color
    let primaryText: Color
    let secondaryText: Color
    let positive: Color
    let negative: Color
    let warning: Color
    let staleOpacity: Double

    static func palette(for scheme: ColorScheme) -> StockPalette {
        switch scheme {
        case .dark:
            return StockPalette(
                screenBackground: Color(red: 0.06, green: 0.07, blue: 0.09),
                groupedSurface: Color(red: 0.13, green: 0.14, blue: 0.17),
                primaryText: Color.white.opacity(0.95),
                secondaryText: Color.white.opacity(0.65),
                positive: Color.green.opacity(0.9),
                negative: Color.red.opacity(0.9),
                warning: Color.orange,
                staleOpacity: 0.45
            )
        case .light:
            fallthrough
        @unknown default:
            return StockPalette(
                screenBackground: Color(UIColor.systemBackground),
                groupedSurface: Color(UIColor.secondarySystemGroupedBackground),
                primaryText: Color(UIColor.label),
                secondaryText: Color(UIColor.secondaryLabel),
                positive: Color.green,
                negative: Color.red,
                warning: Color.orange,
                staleOpacity: 0.48
            )
        }
    }
}
