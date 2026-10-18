//
//  LiveStockTrackerApp.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 17/10/2026.
//

import SwiftUI

@main
struct LiveStockTrackerApp: App {
    private let entries: [StockCatalogEntry]

    init() {
        let logger = OSLogStockLogger()
        entries = (try? CatalogLoading.load(bundle: .main, logger: logger)) ?? []
        print("[setup] catalog entries: \(entries.count)")
        print("[setup] feed URL: \(FeedTransportConfiguration.makeDefaultSocketURL()?.absoluteString ?? "missing")")
        Self.logEveryOrdering(of: entries)
    }

    private static func logEveryOrdering(of entries: [StockCatalogEntry]) {
        let quotes = entries.enumerated().map { index, entry in
            StockQuote(symbol: entry.symbol, price: Decimal(100 + index * 3), previousClose: Decimal(100 + index * 5 % 17),
                       updatedAt: .now)
        }
        for field in SortField.allCases {
            for direction in SortDirection.allCases {
                let top = quotes.sorted(by: SortOption(field: field, direction: direction)).prefix(3).map(\.symbol)
                print("[domain] \(field.rawValue) \(direction.rawValue): \(top.joined(separator: ", ")) ...")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                List(entries) { entry in
                    Text(entry.companyName)
                }
                .navigationTitle("Stocks")
            }
        }
    }
}
