//
//  FailingQuoteStore.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import Foundation
@testable import LiveStockTracker

/// A store whose writes can be made to fail and then recover, to test that disk trouble never stops the feed.
actor FlakyQuoteStore: QuoteStoring {
    struct DiskFull: Error {}

    private(set) var saved: [String: StockQuote] = [:]
    private(set) var failedWrites = 0
    private var failing: Bool

    init(failing: Bool) {
        self.failing = failing
    }

    func setFailing(_ failing: Bool) {
        self.failing = failing
    }

    func loadAll() async throws -> [String: StockQuote] { saved }

    func upsert(_ quotes: [StockQuote]) async throws {
        if failing {
            failedWrites += 1
            throw DiskFull()
        }
        for quote in quotes { saved[quote.symbol] = quote }
    }

    func page(limit: Int, cursor: String?) async throws -> QuotesPage {
        QuotesPage(quotes: saved.values.sorted { $0.symbol < $1.symbol }, nextCursor: nil)
    }

    func hasAny() async throws -> Bool { !saved.isEmpty }
}
