//
//  StockNavigationRoute.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import Foundation

/// Typed navigation destinations for `NavigationStack` (replaces raw symbol strings in the path).
nonisolated enum StockNavigationRoute: Hashable {
    case detail(symbol: String)
}
