//
//  StockPaletteEnvironment.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import SwiftUI

extension EnvironmentValues {
    @Entry var stockPalette = StockPalette.palette(for: .light)
}
