//
//  BatchIngestionTests.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import StockSocketKit
import XCTest
@testable import LiveStockTracker

@MainActor
final class BatchIngestionTests: XCTestCase {
    private let symbols = ["AAA", "BBB", "CCC"]

    private func makeRepository(feed: LifecycleFeed) throws -> FeedTestSystem {
        FeedTestSystem(
            catalogEntries: symbols.map { StockCatalogEntry(symbol: $0, companyName: $0, descriptionText: "D") },
            logging: LifecycleLogging(), echoFeedBuilder: { _ in feed }
        )
    }

    private func payload(_ symbol: String, _ price: Double, epoch: TimeInterval = 1) -> EchoStockPayload {
        EchoStockPayload(symbol: symbol, price: price, previousClose: 100, emittedAtEpoch: epoch)
    }

    func testOneSnapshotUpdatesEverySymbol() async throws {
        let feed = LifecycleFeed()
        let repository = try makeRepository(feed: feed)
        await repository.startFeed.execute()
        await feed.emit(.decodedBatch([payload("AAA", 101), payload("BBB", 102), payload("CCC", 103)]))
        try await eventually { repository.currentMergedQuotes().count == 3 }
        XCTAssertEqual(repository.currentMergedQuotes().map(\.price), [101, 102, 103])
        await repository.stopFeed.execute()
    }

    func testASnapshotIsPublishedToSubscribersAsOneBatch() async throws {
        let feed = LifecycleFeed()
        let repository = try makeRepository(feed: feed)
        let stream = repository.quoteBatches()
        await repository.startFeed.execute()
        await feed.emit(.decodedBatch([payload("AAA", 101), payload("BBB", 102), payload("CCC", 103)]))
        await feed.emit(.decodedBatch([payload("BBB", 104)]))
        var batches: [[String]] = []
        for await batch in stream {
            batches.append(batch.quotes.map(\.symbol))
            if batches.count == 2 { break }
        }
        XCTAssertEqual(batches, [symbols, ["BBB"]])
        await repository.stopFeed.execute()
    }

    func testBatchWithNothingUsableOrNothingNewPublishesNoEvent() async throws {
        let feed = LifecycleFeed()
        let repository = try makeRepository(feed: feed)
        let stream = repository.quoteBatches()
        await repository.startFeed.execute()
        await feed.emit(.decodedBatch([payload("AAA", 120, epoch: 5)]))
        await feed.emit(.decodedBatch([payload("", 1)]))
        await feed.emit(.decodedBatch([payload("AAA", 90, epoch: 3)]))
        await feed.emit(.decodedBatch([payload("BBB", 50, epoch: 6)]))
        var batches: [[String]] = []
        for await batch in stream {
            batches.append(batch.quotes.map(\.symbol))
            if batches.count == 2 { break }
        }
        XCTAssertEqual(batches, [["AAA"], ["BBB"]])
        await repository.stopFeed.execute()
    }

    func testOlderTickCannotOverwriteANewerOne() async throws {
        let feed = LifecycleFeed()
        let repository = try makeRepository(feed: feed)
        await repository.startFeed.execute()
        await feed.emit(.decodedBatch([payload("AAA", 120, epoch: 5)]))
        try await eventually { repository.currentMergedQuotes().first?.price == 120 }
        await feed.emit(.decodedBatch([payload("AAA", 90, epoch: 3)]))
        try await eventually { repository.staleTicksDropped == 1 }
        XCTAssertEqual(repository.currentMergedQuotes().first?.price, 120)
        await feed.emit(.decodedBatch([payload("AAA", 130, epoch: 5)]))
        try await eventually { repository.currentMergedQuotes().first?.price == 130 }
        XCTAssertEqual(repository.staleTicksDropped, 1, "An equal timestamp is a legitimate update")
        await repository.stopFeed.execute()
    }

    func testOneUnusableEntryDoesNotDiscardTheRestOfTheSnapshot() async throws {
        let feed = LifecycleFeed()
        let repository = try makeRepository(feed: feed)
        await repository.startFeed.execute()
        await feed.emit(.decodedBatch([payload("", 1), payload("AAA", 111)]))
        try await eventually { repository.currentMergedQuotes().first?.price == 111 }
        XCTAssertNotEqual(repository.status.currentConnectionState, .failed(reason: .decodingFailed))
        await repository.stopFeed.execute()
    }

    func testGoodSnapshotResetsTheUnusableBatchStreak() async throws {
        let feed = LifecycleFeed()
        let repository = try makeRepository(feed: feed)
        await repository.startFeed.execute()
        let limit = EchoPriceFeed.maxConsecutiveInvalidBatches
        for _ in 0..<(limit - 1) { await feed.emit(.decodedBatch([payload("", 1)])) }
        await feed.emit(.decodedBatch([payload("AAA", 111)]))
        try await eventually { repository.currentMergedQuotes().first?.price == 111 }
        for _ in 0..<(limit - 1) { await feed.emit(.decodedBatch([payload("", 1)])) }
        for _ in 0..<20 { await Task.yield() }
        XCTAssertNotEqual(repository.status.currentConnectionState, .failed(reason: .decodingFailed))
        await repository.stopFeed.execute()
    }

    func testStaleDataFailureMapsToARecoverableTransportState() async throws {
        let feed = LifecycleFeed()
        let repository = try makeRepository(feed: feed)
        await repository.startFeed.execute()
        await feed.emit(.transportFailure(.staleData))
        try await eventually { repository.status.currentConnectionState == .failed(reason: .transportUnavailable) }
        await repository.stopFeed.execute()
    }
}
