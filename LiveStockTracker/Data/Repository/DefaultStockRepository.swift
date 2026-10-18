//
//  DefaultStockRepository.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import Foundation

@MainActor
final class DefaultStockRepository: StockRepositoryProtocol {
    private let catalogEntries: [StockCatalogEntry]
    private let logging: Logging
    private let quoteFanOut = BroadcastFanOut<QuoteBatch>()
    private var latestQuotes: [String: StockQuote] = [:]
    private var liveTimestamps: [String: Date] = [:]
    private(set) var staleTicksDropped = 0

    var isPersistenceDegraded: Bool { false }

    init(catalogEntries: [StockCatalogEntry], logging: Logging) {
        self.catalogEntries = catalogEntries.sorted { $0.symbol < $1.symbol }
        self.logging = logging
    }

    deinit {
        quoteFanOut.finishAll()
    }

    func catalog() async -> [StockCatalogEntry] {
        catalogEntries
    }

    func persistedQuotesSnapshot(limit: Int, cursor: String?) async throws -> QuotesPage {
        QuotesPage(quotes: [], nextCursor: nil)
    }

    func hasPersistedQuotes() async throws -> Bool { false }

    func quoteBatches() -> AsyncStream<QuoteBatch> { quoteFanOut.makeStream() }

    func currentMergedQuotes() -> [StockQuote] { mergedQuotes() }

    func resetQuoteOrdering() { liveTimestamps.removeAll() }

    @discardableResult
    func apply(_ quotes: [StockQuote]) -> Int {
        var accepted: [StockQuote] = []
        for quote in quotes {
            if let newest = liveTimestamps[quote.symbol], quote.updatedAt < newest {
                staleTicksDropped += 1
                continue
            }
            liveTimestamps[quote.symbol] = quote.updatedAt
            accepted.append(quote)
        }
        guard !accepted.isEmpty else { return 0 }
        for quote in accepted { latestQuotes[quote.symbol] = quote }
        quoteFanOut.yield(QuoteBatch(quotes: accepted))
        logging.log(.debug, "Applied \(accepted.count) quote(s)")
        return accepted.count
    }

    private func mergedQuotes() -> [StockQuote] {
        catalogEntries.compactMap { entry in
            latestQuotes[entry.symbol]
        }
    }

    func flushPendingQuotes() async {}
}
