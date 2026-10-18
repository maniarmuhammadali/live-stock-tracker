//
//  FeedTestSystem.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import StockSocketKit
@testable import LiveStockTracker

@MainActor
final class FeedTestSystem: StockRepositoryProtocol {
    let repository: DefaultStockRepository
    let coordinator: FeedSessionCoordinator
    let startFeed: DefaultStartFeedUseCase
    let stopFeed: DefaultStopFeedUseCase
    let retryFeed: DefaultRetryFeedUseCase
    let applySceneActivity: DefaultApplySceneActivityUseCase
    let handleNetworkPathChange: DefaultHandleNetworkPathChangeUseCase
    var status: any FeedStatusProviding { coordinator }
    let networkObserver: FeedNetworkObserver
    var isPersistenceDegraded: Bool { repository.isPersistenceDegraded }
    var staleTicksDropped: Int { repository.staleTicksDropped }

    init(catalogEntries: [StockCatalogEntry], logging: Logging,
         echoFeedBuilder: @escaping ([String]) async -> any StockEchoFeed,
         pathUpdates: @escaping @Sendable () -> AsyncStream<FeedNetworkPath> = { AsyncStream { $0.finish() } }) {
        repository = DefaultStockRepository(catalogEntries: catalogEntries, logging: logging)
        let coordinator = FeedSessionCoordinator(repository: repository, feedBuilder: { symbols in
            EchoPriceFeed(transport: await echoFeedBuilder(symbols), logging: logging)
        })
        self.coordinator = coordinator
        startFeed = DefaultStartFeedUseCase(session: coordinator, status: coordinator, repository: repository)
        stopFeed = DefaultStopFeedUseCase(session: coordinator)
        retryFeed = DefaultRetryFeedUseCase(session: coordinator, repository: repository)
        applySceneActivity = DefaultApplySceneActivityUseCase(session: coordinator)
        handleNetworkPathChange = DefaultHandleNetworkPathChangeUseCase(session: coordinator, status: coordinator)
        networkObserver = FeedNetworkObserver(updates: pathUpdates)
    }

    convenience init(pathUpdates: @escaping @Sendable () -> AsyncStream<FeedNetworkPath> = { AsyncStream { $0.finish() } },
                     builder: @escaping ([String]) async -> any StockEchoFeed) throws {
        self.init(catalogEntries: [StockCatalogEntry(symbol: "AAPL", companyName: "Apple", descriptionText: "D")],
                  logging: LifecycleLogging(), echoFeedBuilder: builder, pathUpdates: pathUpdates)
    }

    func catalog() async -> [StockCatalogEntry] { await repository.catalog() }
    func persistedQuotesSnapshot(limit: Int, cursor: String?) async throws -> QuotesPage {
        try await repository.persistedQuotesSnapshot(limit: limit, cursor: cursor)
    }
    func hasPersistedQuotes() async throws -> Bool { try await repository.hasPersistedQuotes() }
    func quoteBatches() -> AsyncStream<QuoteBatch> { repository.quoteBatches() }
    func currentMergedQuotes() -> [StockQuote] { repository.currentMergedQuotes() }
    @discardableResult func apply(_ quotes: [StockQuote]) -> Int { repository.apply(quotes) }
    func resetQuoteOrdering() { repository.resetQuoteOrdering() }
    func flushPendingQuotes() async { await repository.flushPendingQuotes() }
}
