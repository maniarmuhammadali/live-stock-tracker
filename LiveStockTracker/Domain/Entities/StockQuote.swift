//
//  StockQuote.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 18/10/2026.
//

import Foundation

nonisolated struct StockQuote: Equatable, Hashable, Sendable, Identifiable {
    var id: String { symbol }
    let symbol: String
    let price: Decimal
    let previousClose: Decimal
    let updatedAt: Date

    var dayChange: Decimal {
        price - previousClose
    }

    var dayChangePercent: Decimal {
        guard previousClose != 0 else {
            return 0
        }
        return (dayChange / previousClose) * 100
    }
}
