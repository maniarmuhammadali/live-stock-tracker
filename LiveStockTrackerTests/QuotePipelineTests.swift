//
//  QuotePipelineTests.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import StockSocketKit
import SwiftData
import XCTest
@testable import LiveStockTracker

extension FeedTestSystem {
    var controls: FeedControls {
        FeedControls(status: coordinator, start: startFeed, stop: stopFeed, retry: retryFeed)
    }
}

@MainActor
final class QuotePipelineTests: XCTestCase {
    private func quote(_ price: Decimal, symbol: String = "AAPL") -> StockQuote {
        StockQuote(symbol: symbol, price: price, previousClose: 100, updatedAt: Date(timeIntervalSince1970: 1))
    }

    func testActivationSubscribesBeforeReturning() async throws {
        let repository = MockStockRepository()
        repository.catalogEntries = [StockCatalogEntry(symbol: "AAPL", companyName: "Apple", descriptionText: "D")]
        repository.hasPersistedQuotesValue = .success(true)
        let model = StocksListViewModel(repository: repository, feed: repository.controls)
        await model.activate()
        repository.pushQuote(quote(123))
        try await eventually { model.rows.first?.priceText == CurrencyFormatting.currencyString(for: 123) }
    }

    func testBurstUsesOneWindowAndPublishesLatestQuoteOnBothScreens() async throws {
        let repository = MockStockRepository()
        repository.catalogEntries = [
            StockCatalogEntry(symbol: "AAPL", companyName: "Apple", descriptionText: "D"),
            StockCatalogEntry(symbol: "GOOG", companyName: "Google", descriptionText: "D"),
        ]
        repository.hasPersistedQuotesValue = .success(true)
        repository.mergedQuotes = [quote(100), quote(150, symbol: "GOOG")]
        let listDelay = ManualQuoteDelay()
        let detailDelay = ManualQuoteDelay()
        let list = StocksListViewModel(repository: repository, feed: repository.controls,
                                     sleep: listDelay.sleep)
        let detail = StockDetailViewModel(repository: repository, feedStatus: repository.feed, symbol: "AAPL", sleep: detailDelay.sleep)
        await list.activate()
        await detail.activate()
        await repository.feed.start()
        repository.feed.pushConnectionState(.connected)
        for _ in 0..<20 { await Task.yield() }
        repository.pushQuote(quote(120))
        try await eventually { listDelay.sleeps == 1 && detailDelay.sleeps == 1 }
        repository.pushQuote(quote(200))
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(listDelay.sleeps, 1, "A burst must not restart the refresh window")
        XCTAssertEqual(detailDelay.sleeps, 1)
        listDelay.advance()
        detailDelay.advance()
        try await eventually { list.rows.first?.symbol == "AAPL" }
        try await eventually { detail.uiModel?.lastPriceText == CurrencyFormatting.currencyString(for: 200) }
        XCTAssertEqual(list.rows.first?.priceText, detail.uiModel?.lastPriceText)
        XCTAssertEqual(list.rows.first?.movementLine, detail.uiModel?.movementLine)
        list.sortOption = SortOption(field: .price, direction: .ascending)
        XCTAssertEqual(list.rows.map(\.symbol), ["GOOG", "AAPL"])
        list.sortOption = SortOption(field: .priceChange, direction: .descending)
        XCTAssertEqual(list.rows.map(\.symbol), ["AAPL", "GOOG"])
        list.deactivate()
        detail.deactivate()
        listDelay.advance()
        detailDelay.advance()
    }

    func testDeactivationCancelsPendingDetailPublication() async throws {
        let repository = MockStockRepository()
        repository.catalogEntries = [StockCatalogEntry(symbol: "AAPL", companyName: "Apple", descriptionText: "D")]
        repository.mergedQuotes = [quote(100)]
        let delay = ManualQuoteDelay()
        let detail = StockDetailViewModel(repository: repository, feedStatus: repository.feed, symbol: "AAPL", sleep: delay.sleep)
        await detail.activate()
        for _ in 0..<20 { await Task.yield() }
        repository.pushQuote(quote(200))
        try await eventually { delay.sleeps == 1 }
        detail.deactivate()
        delay.advance()
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(detail.uiModel?.lastPriceText, CurrencyFormatting.currencyString(for: 100))
    }

    func testLiveQuoteFlowsThroughRealRepositoryToBothScreens() async throws {
        let feed = LifecycleFeed()
        let container = try ModelContainer(for: PersistedQuote.self,
                                          configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let repository = FeedTestSystem(
            modelContainer: container,
            catalogEntries: [StockCatalogEntry(symbol: "AAPL", companyName: "Apple", descriptionText: "D")],
            logging: LifecycleLogging(), echoFeedBuilder: { _ in feed }
        )
        let list = StocksListViewModel(repository: repository, feed: repository.controls)
        let detail = StockDetailViewModel(repository: repository, feedStatus: repository.status, symbol: "AAPL")
        await list.activate()
        await detail.activate()
        await list.startStreaming()
        await feed.emit(.decodedBatch([EchoStockPayload(symbol: "AAPL", price: 125, previousClose: 100, emittedAtEpoch: 1)]))
        try await eventually { list.rows.first?.priceText == CurrencyFormatting.currencyString(for: 125) }
        try await eventually { detail.uiModel?.lastPriceText == list.rows.first?.priceText }
        XCTAssertEqual(list.rows.first?.movementLine, detail.uiModel?.movementLine)
        await feed.emit(.decodedBatch([EchoStockPayload(symbol: "AAPL", price: 90, previousClose: 100, emittedAtEpoch: 2)]))
        try await eventually { list.rows.first?.priceText == CurrencyFormatting.currencyString(for: 90) }
        try await eventually { detail.uiModel?.lastPriceText == list.rows.first?.priceText }
        XCTAssertEqual(list.rows.first?.movementPositive, false)
        XCTAssertEqual(detail.uiModel?.movementPositive, false)
        await list.stopStreaming()
        try await eventually { list.rows.first?.stalePresentation == true && detail.uiModel?.stalePresentation == true }
        list.deactivate()
        detail.deactivate()
    }

    func testMultiSymbolBatchTriggersOneRefreshAndDetailIgnoresForeignBatches() async throws {
        let repository = MockStockRepository()
        repository.catalogEntries = [
            StockCatalogEntry(symbol: "AAPL", companyName: "Apple", descriptionText: "D"),
            StockCatalogEntry(symbol: "GOOG", companyName: "Google", descriptionText: "D"),
        ]
        repository.hasPersistedQuotesValue = .success(true)
        repository.mergedQuotes = [quote(100), quote(150, symbol: "GOOG")]
        let listDelay = ManualQuoteDelay()
        let detailDelay = ManualQuoteDelay()
        let list = StocksListViewModel(repository: repository, feed: repository.controls,
                                     sleep: listDelay.sleep)
        let detail = StockDetailViewModel(repository: repository, feedStatus: repository.feed, symbol: "AAPL", sleep: detailDelay.sleep)
        await list.activate()
        await detail.activate()
        repository.pushBatch([quote(110, symbol: "GOOG"), quote(160, symbol: "MSFT")])
        try await eventually { listDelay.sleeps == 1 }
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(detailDelay.sleeps, 0, "A batch without AAPL must not refresh the AAPL detail screen")
        repository.pushBatch([quote(121), quote(111, symbol: "GOOG")])
        try await eventually { detailDelay.sleeps == 1 }
        XCTAssertEqual(listDelay.sleeps, 1, "The list is already inside its refresh window")
        detail.deactivate()
        list.deactivate()
    }

    func testDiskFailureNeverStopsTheLiveFeedAndRecoversWhenDiskDoes() async throws {
        let delay = ManualQuoteDelay()
        let feed = LifecycleFeed()
        let store = FlakyQuoteStore(failing: true)
        let repository = FeedTestSystem(
            store: store,
            catalogEntries: [StockCatalogEntry(symbol: "AAPL", companyName: "Apple", descriptionText: "D")],
            logging: LifecycleLogging(), echoFeedBuilder: { _ in feed }, sleep: delay.sleep
        )
        await repository.startFeed.execute()
        await feed.emit(.connected)
        await feed.emit(.decodedBatch([EchoStockPayload(symbol: "AAPL", price: 120, previousClose: 100, emittedAtEpoch: 1)]))
        try await eventually { delay.sleeps == 1 }
        delay.advance()
        try await eventually { repository.isPersistenceDegraded }

        XCTAssertEqual(repository.status.currentConnectionState, .connected, "A failed write must not interrupt the feed")
        XCTAssertEqual(repository.currentMergedQuotes().first?.price, 120)
        await feed.emit(.decodedBatch([EchoStockPayload(symbol: "AAPL", price: 130, previousClose: 100, emittedAtEpoch: 2)]))
        try await eventually { repository.currentMergedQuotes().first?.price == 130 }
        XCTAssertEqual(repository.status.currentConnectionState, .connected)

        await store.setFailing(false)
        try await eventually { delay.sleeps >= 2 }
        delay.advance()
        try await eventually { !repository.isPersistenceDegraded }
        let saved = await store.saved["AAPL"]
        XCTAssertEqual(saved?.price, 130, "The retry must write the newest quote, not the one that failed")
        await repository.stopFeed.execute()
    }

    func testStopStillCompletesWhileTheDiskIsFailing() async throws {
        let delay = ManualQuoteDelay()
        let feed = LifecycleFeed()
        let repository = FeedTestSystem(
            store: FlakyQuoteStore(failing: true),
            catalogEntries: [StockCatalogEntry(symbol: "AAPL", companyName: "Apple", descriptionText: "D")],
            logging: LifecycleLogging(), echoFeedBuilder: { _ in feed }, sleep: delay.sleep
        )
        await repository.startFeed.execute()
        await feed.emit(.decodedBatch([EchoStockPayload(symbol: "AAPL", price: 120, previousClose: 100, emittedAtEpoch: 1)]))
        try await eventually { delay.sleeps == 1 }
        await repository.stopFeed.execute()
        XCTAssertEqual(repository.status.currentConnectionState, .stopped, "A stop is a stop, not a persistence failure")
        XCTAssertTrue(repository.isPersistenceDegraded)
        XCTAssertEqual(repository.currentMergedQuotes().first?.price, 120)
    }

    func testPersistenceBatchesBurstAndFlushesOnStop() async throws {
        let delay = ManualQuoteDelay()
        let feed = LifecycleFeed()
        let container = try ModelContainer(for: PersistedQuote.self,
                                          configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let repository = FeedTestSystem(
            modelContainer: container,
            catalogEntries: [StockCatalogEntry(symbol: "AAPL", companyName: "Apple", descriptionText: "D")],
            logging: LifecycleLogging(), echoFeedBuilder: { _ in feed }, sleep: delay.sleep
        )
        await repository.startFeed.execute()
        await feed.emit(.decodedBatch([EchoStockPayload(symbol: "AAPL", price: 120, previousClose: 100, emittedAtEpoch: 1)]))
        try await eventually { delay.sleeps == 1 }
        await feed.emit(.decodedBatch([EchoStockPayload(symbol: "AAPL", price: 200, previousClose: 100, emittedAtEpoch: 2)]))
        try await eventually { repository.currentMergedQuotes().first?.price == 200 }
        XCTAssertEqual(delay.sleeps, 1)
        let before = try await repository.persistedQuotesSnapshot(limit: 25, cursor: nil)
        XCTAssertTrue(before.quotes.isEmpty)
        await repository.stopFeed.execute()
        delay.advance()
        let after = try await repository.persistedQuotesSnapshot(limit: 25, cursor: nil)
        XCTAssertEqual(after.quotes.first?.price, 200)
    }
}
