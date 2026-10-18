//
//  FeedLifecycleTests.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import StockSocketKit
import XCTest
@testable import LiveStockTracker

@MainActor
private final class MountGate {
    private var continuation: CheckedContinuation<Void, Never>?
    var entered: (() -> Void)?
    func wait() async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            entered?()
        }
    }
    func release() {
        continuation?.resume()
        continuation = nil
    }
}

@MainActor
final class FeedLifecycleTests: XCTestCase {
    private func makeSystem(builder: @escaping ([String]) async -> any StockEchoFeed) throws -> FeedTestSystem {
        FeedTestSystem(
            catalogEntries: [StockCatalogEntry(symbol: "AAPL", companyName: "Apple", descriptionText: "Description")],
            logging: LifecycleLogging(), echoFeedBuilder: builder
        )
    }

    func testStopWinsOverSuspendedStart() async throws {
        let gate = MountGate()
        let entered = expectation(description: "Feed construction suspended")
        gate.entered = { entered.fulfill() }
        let feed = LifecycleFeed()
        let system = try makeSystem { _ in
            await gate.wait()
            return feed
        }
        let start = Task { await system.startFeed.execute() }
        await fulfillment(of: [entered], timeout: 1)
        await system.stopFeed.execute()
        gate.release()
        await start.value
        // Connected events from an obsolete start must never overwrite Stop.
        await feed.emit(.connected)
        for _ in 0..<10 { await Task.yield() }
        let count = await feed.startCount
        XCTAssertEqual(count, 0)
        XCTAssertFalse(system.status.isStreamingRequested)
        XCTAssertEqual(system.status.currentConnectionState, .stopped)
        await system.stopFeed.execute()
    }

    func testCancellingAnInFlightStartDoesNotLaunchTheLateFeed() async throws {
        let gate = MountGate()
        let entered = expectation(description: "Builder entered")
        gate.entered = { entered.fulfill() }
        let transport = LifecycleFeed()
        let system = try makeSystem { _ in await gate.wait(); return transport }
        let start = Task { await system.startFeed.execute() }
        await fulfillment(of: [entered], timeout: 1)
        start.cancel()
        gate.release()
        await start.value
        let starts = await transport.startCount
        XCTAssertEqual(starts, 0)
        XCTAssertFalse(system.status.isStreamingRequested)
        XCTAssertEqual(system.status.currentConnectionState, .stopped)
        await system.stopFeed.execute()
    }

    func testCancelledOldStartCannotStopANewerRetry() async throws {
        let gate = MountGate()
        let entered = expectation(description: "Old builder entered")
        gate.entered = { entered.fulfill() }
        var builds = 0
        let system = try makeSystem { _ in
            builds += 1
            if builds == 1 { await gate.wait() }
            return LifecycleFeed()
        }
        let start = Task { await system.startFeed.execute() }
        await fulfillment(of: [entered], timeout: 1)
        start.cancel()
        await system.retryFeed.execute()
        try await eventually { system.status.currentConnectionState == .connected }
        gate.release()
        await start.value
        XCTAssertTrue(system.status.isStreamingRequested)
        XCTAssertEqual(system.status.currentConnectionState, .connected)
        await system.stopFeed.execute()
    }

    func testRepeatedStartBuildsOnlyOneFeedWhileMounting() async throws {
        let gate = MountGate()
        let entered = expectation(description: "First builder entered")
        var builds = 0
        let system = try makeSystem { _ in
            builds += 1
            if builds == 1 {
                await gate.wait()
            }
            return LifecycleFeed()
        }
        gate.entered = { entered.fulfill() }
        let first = Task { await system.startFeed.execute() }
        await fulfillment(of: [entered], timeout: 1)
        let second = Task { await system.startFeed.execute() }
        await second.value
        gate.release()
        await first.value
        XCTAssertEqual(builds, 1)
        await system.stopFeed.execute()
    }

    func testMountInheritsSceneSuspensionSetBeforeStart() async throws {
        let feed = LifecycleFeed()
        let system = try makeSystem { _ in feed }
        await system.applySceneActivity.execute(.inactive)
        await system.startFeed.execute()
        let suspended = await feed.suspended
        XCTAssertTrue(suspended)
        await system.stopFeed.execute()
    }
}

private actor DelayedBeginFeed: StockEchoFeed {
    private let stream: AsyncStream<WebSocketPublicEvent>
    private let continuation: AsyncStream<WebSocketPublicEvent>.Continuation
    private var beginGate: CheckedContinuation<Void, Never>?
    private var stops = 0
    private(set) var running = false
    private let onBegin: @Sendable () -> Void
    private let onCleanup: @Sendable () -> Void

    init(onBegin: @escaping @Sendable () -> Void, onCleanup: @escaping @Sendable () -> Void) {
        (stream, continuation) = AsyncStream.makeStream()
        self.onBegin = onBegin
        self.onCleanup = onCleanup
    }
    func eventsStream(
        bufferingPolicy: AsyncStream<WebSocketPublicEvent>.Continuation.BufferingPolicy
    ) -> AsyncStream<WebSocketPublicEvent> { stream }
    func beginTransport() async {
        await withCheckedContinuation { gate in
            beginGate = gate
            onBegin()
        }
        running = true
    }
    func releaseBegin() { beginGate?.resume(); beginGate = nil }
    func stopTransport() {
        running = false
        continuation.finish()
        stops += 1
        if stops == 2 { onCleanup() }
    }
    func requestReconnect() async {}
    func applyOutboundSuspension(_ suspended: Bool) {}
}

extension FeedLifecycleTests {
    func testDelayedBeginIsTornDownIfStopAlreadyCompleted() async throws {
        let entered = expectation(description: "Begin suspended")
        let cleanedUp = expectation(description: "Late begin cleaned up")
        let feed = DelayedBeginFeed(onBegin: { entered.fulfill() }, onCleanup: { cleanedUp.fulfill() })
        let system = try makeSystem { _ in feed }
        await system.startFeed.execute()
        await fulfillment(of: [entered], timeout: 1)
        await system.stopFeed.execute()
        await feed.releaseBegin()
        await fulfillment(of: [cleanedUp], timeout: 1)
        let running = await feed.running
        XCTAssertFalse(running)
        await feed.stopTransport()
    }
}
