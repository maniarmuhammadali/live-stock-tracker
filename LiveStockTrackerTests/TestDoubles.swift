//
//  TestDoubles.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import StockSocketKit
import XCTest
@testable import LiveStockTracker

/// Test transport: the socket package's feed protocol with events and call counters.
actor LifecycleFeed: StockEchoFeed {
    private let stream: AsyncStream<WebSocketPublicEvent>
    private let continuation: AsyncStream<WebSocketPublicEvent>.Continuation
    private(set) var startCount = 0
    private(set) var reconnectCount = 0
    private(set) var suspended = false

    init() { (stream, continuation) = AsyncStream.makeStream() }
    func eventsStream(
        bufferingPolicy: AsyncStream<WebSocketPublicEvent>.Continuation.BufferingPolicy
    ) -> AsyncStream<WebSocketPublicEvent> {
        stream
    }
    func beginTransport() {
        startCount += 1
        continuation.yield(.connected)
    }
    func stopTransport() { continuation.finish() }
    func requestReconnect() async { reconnectCount += 1 }
    func applyOutboundSuspension(_ suspended: Bool) { self.suspended = suspended }
    func emit(_ event: WebSocketPublicEvent) { continuation.yield(event) }
}

/// Records session commands and lets a test push connection state.
@MainActor
final class MockFeedSession: FeedSessionControlling, FeedStatusProviding {
    private let connections = BroadcastFanOut<FeedConnectionState>()
    private(set) var isStreamingRequested = false
    private(set) var currentConnectionState: FeedConnectionState = .idle
    func connectionEvents() -> AsyncStream<FeedConnectionState> { connections.makeStream() }
    func start() async { isStreamingRequested = true }
    func stop() async { isStreamingRequested = false; pushConnectionState(.stopped) }
    func retry() async { isStreamingRequested = true }
    func reconnect() async {}
    func setSceneActive(_ isActive: Bool) async {}
    func pushConnectionState(_ state: FeedConnectionState) {
        currentConnectionState = state
        if case .failed = state { isStreamingRequested = false }
        connections.yield(state)
    }
}

@MainActor
final class MockStockRepository: StockRepositoryProtocol {
    let feed = MockFeedSession()

    private let quotes = BroadcastFanOut<QuoteBatch>()

    var catalogEntries: [StockCatalogEntry] = []
    var hasPersistedQuotesValue: Result<Bool, Error> = .success(false)

    var isPersistenceDegraded = false

    var mergedQuotes: [StockQuote] = []

    func catalog() async -> [StockCatalogEntry] {
        catalogEntries
    }

    func persistedQuotesSnapshot(limit: Int, cursor: String?) async throws -> QuotesPage {
        QuotesPage(quotes: [], nextCursor: nil)
    }

    func hasPersistedQuotes() async throws -> Bool {
        try hasPersistedQuotesValue.get()
    }

    func quoteBatches() -> AsyncStream<QuoteBatch> {
        quotes.makeStream()
    }

    func currentMergedQuotes() -> [StockQuote] {
        mergedQuotes
    }

    @discardableResult func apply(_ quotes: [StockQuote]) -> Int { pushBatch(quotes); return quotes.count }
    private(set) var orderingResets = 0
    func resetQuoteOrdering() { orderingResets += 1 }
    func flushPendingQuotes() async {}

    func pushQuote(_ quote: StockQuote) {
        mergedQuotes.removeAll { $0.symbol == quote.symbol }
        mergedQuotes.append(quote)
        quotes.yield(QuoteBatch(quotes: [quote]))
    }

    func pushBatch(_ batch: [StockQuote]) {
        for quote in batch { mergedQuotes.removeAll { $0.symbol == quote.symbol } }
        mergedQuotes.append(contentsOf: batch)
        quotes.yield(QuoteBatch(quotes: batch))
    }
}
