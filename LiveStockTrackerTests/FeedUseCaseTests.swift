//
//  FeedUseCaseTests.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import StockSocketKit
import XCTest
@testable import LiveStockTracker

@MainActor
final class FeedUseCaseTests: XCTestCase {
    func testConnectivityChangesNeverStartAStoppedFeed() async throws {
        var builds = 0
        let (paths, continuation) = AsyncStream<FeedNetworkPath>.makeStream()
        let system = try FeedTestSystem(pathUpdates: { paths }, builder: { _ in builds += 1; return LifecycleFeed() })
        continuation.yield(FeedNetworkPath(isSatisfied: false, interfaces: []))
        continuation.yield(FeedNetworkPath(isSatisfied: true, interfaces: ["wifi"]))
        continuation.finish()
        await system.networkObserver.observeChanges(using: system.handleNetworkPathChange)
        XCTAssertEqual(builds, 0)
        XCTAssertFalse(system.status.isStreamingRequested)
    }

    func testTerminalFailureNeedsExplicitRetryAfterNetworkChange() async throws {
        let first = LifecycleFeed()
        var builds = 0
        let (paths, continuation) = AsyncStream<FeedNetworkPath>.makeStream()
        let system = try FeedTestSystem(pathUpdates: { paths }, builder: { _ in
            builds += 1
            return builds == 1 ? first : LifecycleFeed()
        })
        await system.startFeed.execute()
        await first.emit(.transportFailure(.closedByServer(code: 1000)))
        try await eventually { system.status.currentConnectionState == .failed(reason: .closedByServer) }
        XCTAssertFalse(system.status.isStreamingRequested)
        continuation.yield(FeedNetworkPath(isSatisfied: true, interfaces: ["cellular"]))
        continuation.yield(FeedNetworkPath(isSatisfied: true, interfaces: ["wifi"]))
        continuation.finish()
        await system.networkObserver.observeChanges(using: system.handleNetworkPathChange)
        XCTAssertEqual(builds, 1)
        await system.retryFeed.execute()
        try await eventually { system.status.currentConnectionState == .connected }
        XCTAssertEqual(builds, 2)
        await system.stopFeed.execute()
    }

    func testScenePolicyIsAppliedBeforeAndAfterStart() async throws {
        let transport = LifecycleFeed()
        let system = try FeedTestSystem { _ in transport }
        await system.applySceneActivity.execute(.inactive)
        await system.startFeed.execute()
        let initiallySuspended = await transport.suspended
        XCTAssertTrue(initiallySuspended)
        await system.applySceneActivity.execute(.active)
        let resumed = await transport.suspended
        XCTAssertFalse(resumed)
        await system.stopFeed.execute()
    }

    func testUnexpectedStreamEndClearsIntentAndRequiresRetry() async throws {
        let transport = LifecycleFeed()
        let system = try FeedTestSystem { _ in transport }
        await system.startFeed.execute()
        try await eventually { system.status.currentConnectionState == .connected }
        await transport.stopTransport()
        try await eventually { system.status.currentConnectionState == .failed(reason: .transportUnavailable) }
        XCTAssertFalse(system.status.isStreamingRequested)
        await system.stopFeed.execute()
    }

    func testCancelledStartCannotChangeIntent() async throws {
        let system = try FeedTestSystem { _ in LifecycleFeed() }
        let start = Task {
            try? await Task.sleep(for: .seconds(60))
            await system.startFeed.execute()
        }
        start.cancel()
        await start.value
        XCTAssertFalse(system.status.isStreamingRequested)
        XCTAssertEqual(system.status.currentConnectionState, .idle)
    }
}
