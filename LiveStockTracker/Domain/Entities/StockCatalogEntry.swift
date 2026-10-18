//
//  StockCatalogEntry.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 18/10/2026.
//

import Foundation

nonisolated struct StockCatalogEntry: Equatable, Hashable, Sendable, Identifiable {
    var id: String { symbol }
    let symbol: String
    let companyName: String
    let descriptionText: String

}
