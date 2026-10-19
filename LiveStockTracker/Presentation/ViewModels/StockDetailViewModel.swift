//
//  StockDetailViewModel.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import Foundation
import Observation

@Observable @MainActor
final class StockDetailViewModel {
    private let repository: any StockRepositoryProtocol
    private let feedStatus: any FeedStatusProviding
    private let symbol: String
    @ObservationIgnored private let observer: LiveQuoteObserver

    private(set) var uiModel: StockDetailUIModel?
    private var catalogEntry: StockCatalogEntry?
    private var connectionState: FeedConnectionState = .idle

    init(
        repository: any StockRepositoryProtocol,
        feedStatus: any FeedStatusProviding,
        symbol: String,
        sleep: @escaping @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.repository = repository
        self.feedStatus = feedStatus
        self.symbol = symbol
        observer = LiveQuoteObserver(repository: repository, feedStatus: feedStatus, sleep: sleep)
    }

    func activate() async {
        deactivate()

        let entries = await repository.catalog()
        catalogEntry = entries.first { $0.symbol == symbol }

        guard catalogEntry != nil else {
            uiModel = nil
            return
        }

        connectionState = feedStatus.currentConnectionState
        rebuildFromLatestQuote()

        observer.start(
            symbol: symbol,
            onConnection: { [weak self] state in
                self?.connectionState = state
                self?.rebuildFromLatestQuote()
            },
            onQuotes: { [weak self] in
                self?.rebuildFromLatestQuote()
            }
        )
    }

    func deactivate() {
        observer.stop()
    }

    private func rebuildFromLatestQuote() {
        guard let catalogEntry else {
            uiModel = nil
            return
        }

        let quote = repository.currentMergedQuotes().first { $0.symbol == symbol }
        let stale = LiveQuoteObserver.isStale(feedStatus: feedStatus, connectionState: connectionState)
        uiModel = StockUIMapper.detailUIModel(catalog: catalogEntry, quote: quote, stalePresentation: stale)
    }
}
