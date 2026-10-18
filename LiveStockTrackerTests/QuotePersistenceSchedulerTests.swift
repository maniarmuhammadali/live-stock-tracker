//
//  QuotePersistenceSchedulerTests.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import XCTest
@testable import LiveStockTracker

@MainActor
final class QuotePersistenceSchedulerTests: XCTestCase {
    private func quote(_ symbol: String, _ price: Decimal) -> StockQuote {
        StockQuote(symbol: symbol, price: price, previousClose: 100, updatedAt: Date(timeIntervalSince1970: 1))
    }

    private func waitUntil(_ condition: () async -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(2)
        while await !condition() {
            guard ContinuousClock.now < deadline else {
                XCTFail("Condition did not become true")
                throw CancellationError()
            }
            try await Task.sleep(for: .milliseconds(1))
        }
    }

    private func make(store: FlakyQuoteStore) -> (QuotePersistenceScheduler, ManualQuoteDelay) {
        let delay = ManualQuoteDelay()
        return (QuotePersistenceScheduler(store: store, logging: LifecycleLogging(), sleep: delay.sleep), delay)
    }

    func testQuotesInsideTheWindowAreWrittenTogetherNewestWins() async throws {
        let store = FlakyQuoteStore(failing: false)
        let (scheduler, delay) = make(store: store)
        scheduler.enqueue([quote("AAA", 1)])
        scheduler.enqueue([quote("AAA", 2), quote("BBB", 3)])
        try await eventually { delay.sleeps == 1 }
        scheduler.enqueue([quote("CCC", 4)])
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(delay.sleeps, 1, "A burst shares one window")
        delay.advance()
        try await waitUntil { await store.saved.count == 3 }
        let saved = await store.saved
        XCTAssertEqual(saved["AAA"]?.price, 2)
        XCTAssertFalse(scheduler.isDegraded)
    }

    func testFailedWriteFlagsDegradedKeepsNewestAndRecovers() async throws {
        let store = FlakyQuoteStore(failing: true)
        let (scheduler, delay) = make(store: store)
        scheduler.enqueue([quote("AAA", 1)])
        try await eventually { delay.sleeps == 1 }
        delay.advance()
        try await eventually { scheduler.isDegraded }
        scheduler.enqueue([quote("AAA", 2)])
        await store.setFailing(false)
        try await eventually { delay.sleeps == 2 }
        delay.advance()
        try await eventually { !scheduler.isDegraded }
        let saved = await store.saved["AAA"]
        XCTAssertEqual(saved?.price, 2, "The retry writes the newest quote, not the one that failed")
    }

    func testFlushNowWritesImmediatelyAndCancelsTheTimer() async {
        let store = FlakyQuoteStore(failing: false)
        let (scheduler, delay) = make(store: store)
        scheduler.enqueue([quote("AAA", 1)])
        await scheduler.flushNow()
        let saved = await store.saved["AAA"]
        XCTAssertEqual(saved?.price, 1)
        delay.advance()
        for _ in 0..<20 { await Task.yield() }
        let count = await store.saved.count
        XCTAssertEqual(count, 1)
    }

    func testFlushNowWithNothingPendingIsANoOp() async {
        let store = FlakyQuoteStore(failing: true)
        let (scheduler, _) = make(store: store)
        await scheduler.flushNow()
        let failed = await store.failedWrites
        XCTAssertEqual(failed, 0)
        XCTAssertFalse(scheduler.isDegraded)
    }
}
