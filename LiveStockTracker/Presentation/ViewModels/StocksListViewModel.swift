//
//  StocksListViewModel.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import Foundation
import Observation

@Observable @MainActor
final class StocksListViewModel {
    private let repository: any StockRepositoryProtocol
    private let feed: FeedControls
    @ObservationIgnored private let observer: LiveQuoteObserver

    private(set) var rows: [StockRowUIModel] = []
    private(set) var connectionState: FeedConnectionState = .idle
    private(set) var failurePresentation: MessagePresentation?
    private(set) var hasCachedQuotes = false
    private(set) var isStreamingRequested = false
    /// Saving for offline use is failing, live prices still update. Shown as a banner, never as a blocking error.
    private(set) var isPersistenceDegraded = false

    private var catalog: [StockCatalogEntry] = []
    private let startsFeedOnLaunch: Bool
    private var didStartOnLaunch = false

    var sortOption: SortOption = .default {
        didSet {
            guard sortOption != oldValue else { return }
            rebuildRows()
        }
    }

    init(
        repository: any StockRepositoryProtocol,
        feed: FeedControls,
        startsFeedOnLaunch: Bool = false,
        sleep: @escaping @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.repository = repository
        self.feed = feed
        self.startsFeedOnLaunch = startsFeedOnLaunch
        observer = LiveQuoteObserver(repository: repository, feedStatus: feed.status, sleep: sleep)
    }

    var onboardingActive: Bool {
        hasCachedQuotes == false && feed.status.isStreamingRequested == false
    }

    func activate() async {
        catalog = await repository.catalog()

        await refreshCachedFlag()
        refreshRepositoryFlags()
        connectionState = feed.status.currentConnectionState
        rebuildRows()
        observer.start(
            onConnection: { [weak self] state in self?.apply(connectionState: state) },
            onQuotes: { [weak self] in self?.applyQuoteRefresh() }
        )
        if startsFeedOnLaunch, !didStartOnLaunch {
            didStartOnLaunch = true
            await startStreaming()
        }
    }

    func startStreaming() async {
        failurePresentation = nil
        await feed.start.execute()
        await refreshCachedFlag()
        refreshRepositoryFlags()
        rebuildRows()
    }

    func stopStreaming() async {
        await feed.stop.execute()
        refreshRepositoryFlags()
        rebuildRows()
    }

    func retryAfterFailure() async {
        failurePresentation = nil
        await feed.retry.execute()
        await refreshCachedFlag()
        refreshRepositoryFlags()
        rebuildRows()
    }

    func deactivate() {
        observer.stop()
    }

    private func refreshCachedFlag() async {
        do {
            hasCachedQuotes = try await repository.hasPersistedQuotes()
        } catch {
            failurePresentation = .persistenceFailure
            hasCachedQuotes = false
        }
    }

    private func apply(connectionState state: FeedConnectionState) {
        connectionState = state
        switch state {
        case let .failed(reason):
            failurePresentation = MessagePresentationMapper.map(failure: reason)
        case .connected, .connecting, .reconnecting:
            failurePresentation = nil
        case .idle, .stopped:
            break
        }
        refreshRepositoryFlags()
        rebuildRows()
    }

    private func applyQuoteRefresh() {
        hasCachedQuotes = true
        refreshRepositoryFlags()
        rebuildRows()
    }

    private func refreshRepositoryFlags() {
        isStreamingRequested = feed.status.isStreamingRequested
        isPersistenceDegraded = repository.isPersistenceDegraded
    }

    private func rebuildRows() {
        if onboardingActive {
            rows = []
            return
        }

        let stale = LiveQuoteObserver.isStale(feedStatus: feed.status, connectionState: connectionState)
        let quotes = repository.currentMergedQuotes()
        let quotesBySymbol = Dictionary(uniqueKeysWithValues: quotes.map { ($0.symbol, $0) })
        func row(for entry: StockCatalogEntry) -> StockRowUIModel {
            StockUIMapper.rowUIModel(catalog: entry, quote: quotesBySymbol[entry.symbol], stalePresentation: stale)
        }

        let entriesBySymbol = Dictionary(uniqueKeysWithValues: catalog.map { ($0.symbol, $0) })
        let quoted = quotes.sorted(by: sortOption).compactMap { entriesBySymbol[$0.symbol] }
        let pending = catalog.filter { quotesBySymbol[$0.symbol] == nil }.sorted { $0.symbol < $1.symbol }
        let updated = (quoted + pending).map(row(for:))
        if updated != rows { rows = updated }
    }
}
