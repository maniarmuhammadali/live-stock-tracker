//
//  LiveQuoteObserver.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import Foundation

/// Subscribes to the repository's connection and quote-batch streams and turns bursts into one UI refresh per
/// coalescing window. Both screens use it, so the subscription, cancellation and throttling live in one place.
@MainActor
final class LiveQuoteObserver {
    private let repository: any StockRepositoryProtocol
    private let feedStatus: any FeedStatusProviding
    private let sleep: @MainActor (Duration) async throws -> Void
    private var connectionTask: Task<Void, Never>?
    private var quoteTask: Task<Void, Never>?
    private var coalesceTask: Task<Void, Never>?

    init(
        repository: any StockRepositoryProtocol,
        feedStatus: any FeedStatusProviding,
        sleep: @escaping @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.repository = repository
        self.feedStatus = feedStatus
        self.sleep = sleep
    }

    deinit {
        connectionTask?.cancel()
        quoteTask?.cancel()
        coalesceTask?.cancel()
    }

    /// Streams are created before this returns, so no event between now and the first await is missed.
    /// `symbol` narrows quote refreshes to batches that contain it; nil means any batch.
    func start(
        symbol: String? = nil,
        onConnection: @escaping @MainActor (FeedConnectionState) -> Void,
        onQuotes: @escaping @MainActor () -> Void
    ) {
        stop()
        let connections = feedStatus.connectionEvents()
        let batches = repository.quoteBatches()
        connectionTask = Task { @MainActor [weak self] in
            for await state in connections {
                guard self != nil, !Task.isCancelled else { break }
                onConnection(state)
            }
        }
        quoteTask = Task { @MainActor [weak self] in
            for await batch in batches {
                guard let self, !Task.isCancelled else { break }
                if let symbol, !batch.contains(symbol: symbol) { continue }
                self.scheduleCoalesced(onQuotes)
            }
        }
    }

    func stop() {
        connectionTask?.cancel()
        quoteTask?.cancel()
        coalesceTask?.cancel()
        connectionTask = nil
        quoteTask = nil
        coalesceTask = nil
    }

    private func scheduleCoalesced(_ onQuotes: @escaping @MainActor () -> Void) {
        guard coalesceTask == nil else { return }
        let sleep = sleep
        coalesceTask = Task { @MainActor [weak self] in
            do {
                try await sleep(QuoteStreamPresentationTiming.uiRefreshCoalesce)
                try Task.checkCancellation()
            } catch { return }
            guard let self else { return }
            self.coalesceTask = nil
            onQuotes()
        }
    }

    /// Values read from the repository may be stale: anything not live-and-connected is shown dimmed.
    static func isStale(feedStatus: any FeedStatusProviding, connectionState: FeedConnectionState) -> Bool {
        let connectedLive = feedStatus.isStreamingRequested && connectionState == .connected
        return connectedLive == false
    }
}
