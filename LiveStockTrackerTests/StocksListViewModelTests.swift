//
//  StocksListViewModelTests.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import XCTest

@testable import LiveStockTracker

extension MockStockRepository {
    var controls: FeedControls {
        FeedControls(
            status: feed,
            start: DefaultStartFeedUseCase(session: feed, status: feed, repository: self),
            stop: DefaultStopFeedUseCase(session: feed),
            retry: DefaultRetryFeedUseCase(session: feed, repository: self)
        )
    }
}

@MainActor
final class StocksListViewModelTests: XCTestCase {
    func testPersistenceFailureMapsToPersistenceMessage() async {
        let repository = MockStockRepository()
        repository.hasPersistedQuotesValue = .success(true)

        let model = StocksListViewModel(repository: repository, feed: repository.controls)
        await model.activate()

        // `activate()` subscribes before returning, so the event is not missed; yielding lets it be delivered.
        repository.feed.pushConnectionState(.failed(reason: .persistenceFailed))
        for _ in 0..<20 where model.failurePresentation == nil { await Task.yield() }

        XCTAssertEqual(model.failurePresentation, .persistenceFailure)
        model.deactivate()
    }

    func testStreamingStartUpdatesRowsWhenCacheExists() async throws {
        let repository = MockStockRepository()

        repository.catalogEntries = [
            StockCatalogEntry(symbol: "ZZZ", companyName: "Zed", descriptionText: "D"),
        ]
        repository.hasPersistedQuotesValue = .success(true)
        repository.mergedQuotes = [
            StockQuote(symbol: "ZZZ", price: 10, previousClose: 9, updatedAt: Date(timeIntervalSince1970: 1)),
        ]

        let model = StocksListViewModel(repository: repository, feed: repository.controls)
        await model.activate()
        XCTAssertEqual(model.rows.map(\.symbol), ["ZZZ"], "Cached quotes show before the feed starts")

        await model.startStreaming()

        XCTAssertTrue(model.isStreamingRequested)
        XCTAssertEqual(model.rows.map(\.symbol), ["ZZZ"])
        model.deactivate()
    }

    func testFeedStartsOnLaunchOnlyOnce() async {
        let repository = MockStockRepository()
        let model = StocksListViewModel(repository: repository, feed: repository.controls, startsFeedOnLaunch: true)

        await model.activate()
        XCTAssertTrue(model.isStreamingRequested, "The list is live as soon as it appears")
        XCTAssertFalse(model.onboardingActive)

        await model.stopStreaming()
        await model.activate()
        XCTAssertFalse(model.isStreamingRequested, "Activating again must not override the user's Stop")
    }

    func testFeedWaitsForStartWhenLaunchStartIsOff() async {
        let repository = MockStockRepository()
        let model = StocksListViewModel(repository: repository, feed: repository.controls)

        await model.activate()
        XCTAssertFalse(model.isStreamingRequested)
        XCTAssertTrue(model.onboardingActive)
    }
}
