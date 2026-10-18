//
//  QuoteBatch.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 18/10/2026.
//

import Foundation

nonisolated struct QuoteBatch: Equatable, Sendable {
    let quotes: [StockQuote]

    func contains(symbol: String) -> Bool {
        quotes.contains { $0.symbol == symbol }
    }
}
