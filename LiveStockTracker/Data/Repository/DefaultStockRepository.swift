//
//  DefaultStockRepository.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import Foundation
import SwiftData

@MainActor
final class DefaultStockRepository: StockRepositoryProtocol {
    private let store: any QuoteStoring
    private let catalogEntries: [StockCatalogEntry]
    private let logging: Logging
    private let persistence: QuotePersistenceScheduler
    private let quoteFanOut = BroadcastFanOut<QuoteBatch>()
    private var latestQuotes: [String: StockQuote] = [:]
    private var liveTimestamps: [String: Date] = [:]
    private(set) var staleTicksDropped = 0
    private var hydrationTask: Task<Void, Never>?

    var isPersistenceDegraded: Bool { persistence.isDegraded }

    init(
        store: any QuoteStoring,
        catalogEntries: [StockCatalogEntry],
        logging: Logging,
        sleep: @escaping @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.store = store
        self.persistence = QuotePersistenceScheduler(store: store, logging: logging, sleep: sleep)
        self.catalogEntries = catalogEntries.sorted { $0.symbol < $1.symbol }
        self.logging = logging
        hydrationTask = Task { @MainActor [weak self] in await self?.hydrateFromPersistence() }
    }

    convenience init(
        modelContainer: ModelContainer,
        catalogEntries: [StockCatalogEntry],
        logging: Logging,
        sleep: @escaping @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.init(store: SwiftDataQuoteStore(modelContainer: modelContainer),
                  catalogEntries: catalogEntries, logging: logging, sleep: sleep)
    }

    deinit {
        hydrationTask?.cancel()
        quoteFanOut.finishAll()
    }

    func catalog() async -> [StockCatalogEntry] {
        await hydrationTask?.value
        return catalogEntries
    }

    func persistedQuotesSnapshot(limit: Int, cursor: String?) async throws -> QuotesPage {
        try await store.page(limit: limit, cursor: cursor)
    }

    func hasPersistedQuotes() async throws -> Bool { try await store.hasAny() }

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
        persistence.enqueue(accepted)
        return accepted.count
    }

    /// Loads the offline cache off the main actor. A live tick that already arrived is newer than any cached row.
    private func hydrateFromPersistence() async {
        do {
            let cached = try await store.loadAll()
            for (symbol, quote) in cached where latestQuotes[symbol] == nil {
                latestQuotes[symbol] = quote
            }
        } catch {
            logging.log(.error, "Hydration failed \(error.localizedDescription)")
        }
    }

    private func mergedQuotes() -> [StockQuote] {
        catalogEntries.compactMap { entry in
            latestQuotes[entry.symbol]
        }
    }

    func flushPendingQuotes() async { await persistence.flushNow() }
}
