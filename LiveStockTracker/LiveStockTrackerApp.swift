//
//  LiveStockTrackerApp.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 17/10/2026.
//

import StockSocketKit
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
        Self.logEchoedSnapshots(symbols: entries.map(\.symbol), logger: logger)
    }

    private static func logEchoedSnapshots(symbols: [String], logger: Logging) {
        guard let url = FeedTransportConfiguration.makeDefaultSocketURL() else { return }
        let session = EchoWebSocketSession(
            url: url, symbols: symbols, outboundIntervalNanoseconds: EchoTransportDefaults.outboundIntervalNanoseconds,
            backoffPolicy: .standard, logger: LoggingEchoBridge(logging: logger)
        )
        Task {
            let events = await session.wireEventsStream()
            await session.start()

            for await event in events {
                switch event {
                case let .decodedBatch(batch):
                    let sample = batch.prefix(3).map { "\($0.symbol) \(String(format: "%.2f", $0.price))" }
                    print("[socket] snapshot of \(batch.count): \(sample.joined(separator: ", ")) ...")
                default:
                    print("[socket] \(event)")
                }
            }
        }
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
