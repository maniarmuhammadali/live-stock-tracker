//
//  PersistedQuote.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import Foundation
import SwiftData

@Model
final class PersistedQuote {
    @Attribute(.unique) var symbol: String
    /// Prices are stored as strings so Decimal values survive exactly; SwiftData would round-trip them through Double.
    var priceString: String
    var previousCloseString: String
    var updatedAt: Date

    init(symbol: String, priceString: String, previousCloseString: String, updatedAt: Date) {
        self.symbol = symbol
        self.priceString = priceString
        self.previousCloseString = previousCloseString
        self.updatedAt = updatedAt
    }
}
