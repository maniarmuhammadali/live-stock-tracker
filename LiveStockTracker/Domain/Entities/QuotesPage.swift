//
//  QuotesPage.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 18/10/2026.
//

import Foundation

nonisolated struct QuotesPage: Equatable, Sendable {
    let quotes: [StockQuote]
    let nextCursor: String?

}
