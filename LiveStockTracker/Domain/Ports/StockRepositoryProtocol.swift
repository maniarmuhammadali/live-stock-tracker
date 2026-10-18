//
//  StockRepositoryProtocol.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 18/10/2026.
//

import Foundation

@MainActor
protocol StockRepositoryProtocol: AnyObject {
    /// Saving quotes for offline use keeps failing. Live prices are unaffected; only the cache is out of date.
    var isPersistenceDegraded: Bool { get }

    func catalog() async -> [StockCatalogEntry]

    /// Paged persisted quotes ascending by symbol. `cursor` is the prior page's opaque `nextCursor` (empty same as nil).
    func persistedQuotesSnapshot(limit: Int, cursor: String?) async throws -> QuotesPage
    func hasPersistedQuotes() async throws -> Bool

    func quoteBatches() -> AsyncStream<QuoteBatch>
    func currentMergedQuotes() -> [StockQuote]

    /// Merge valid domain quotes and publish a single batch. Returns the accepted quote count.
    @discardableResult func apply(_ quotes: [StockQuote]) -> Int

    func resetQuoteOrdering()
    func flushPendingQuotes() async
}
