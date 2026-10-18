//
//  FeedNetworkRecoveryTests.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import XCTest
@testable import LiveStockTracker

@MainActor
final class FeedNetworkRecoveryTests: XCTestCase {
    func testSatisfiedCellularToWiFiAndBackReconnectsRequestedFeed() async throws {
        let transport = LifecycleFeed()
        let (stream, continuation) = AsyncStream<FeedNetworkPath>.makeStream()
        let system = try FeedTestSystem(pathUpdates: { stream }, builder: { _ in transport })
        await system.startFeed.execute()
        continuation.yield(FeedNetworkPath(isSatisfied: true, interfaces: ["cellular:pdp_ip0"]))
        continuation.yield(FeedNetworkPath(isSatisfied: true, interfaces: ["wifi:en0"]))
        continuation.yield(FeedNetworkPath(isSatisfied: true, interfaces: ["wifi:en0"]))
        continuation.yield(FeedNetworkPath(isSatisfied: true, interfaces: ["cellular:pdp_ip0"]))
        continuation.finish()
        await system.networkObserver.observeChanges(using: system.handleNetworkPathChange)
        let reconnects = await transport.reconnectCount
        XCTAssertEqual(reconnects, 2, "Only actual interface changes request a reconnect through transport backoff")
        await system.stopFeed.execute()
    }

    func testConnectivityRecoveryDoesNotUndoUserStop() async throws {
        let transport = LifecycleFeed()
        let (stream, continuation) = AsyncStream<FeedNetworkPath>.makeStream()
        let system = try FeedTestSystem(pathUpdates: { stream }, builder: { _ in transport })
        await system.startFeed.execute()
        await system.stopFeed.execute()
        continuation.yield(FeedNetworkPath(isSatisfied: false, interfaces: []))
        continuation.yield(FeedNetworkPath(isSatisfied: true, interfaces: ["wifi:en0"]))
        continuation.finish()
        await system.networkObserver.observeChanges(using: system.handleNetworkPathChange)
        let reconnects = await transport.reconnectCount
        XCTAssertEqual(reconnects, 0)
        XCTAssertFalse(system.status.isStreamingRequested)
        XCTAssertEqual(system.status.currentConnectionState, .stopped)
    }
}
