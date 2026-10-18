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
