//
//  EchoPriceFeedTests.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import StockSocketKit
import XCTest
@testable import LiveStockTracker

@MainActor
final class EchoPriceFeedTests: XCTestCase {
    func testFailureTranslationCoversEveryTransportFailure() async throws {
        let cases: [(WebSocketTransportFailure, FeedFailure)] = [
            (.heartbeatTimedOut, .transportUnavailable), (.sendTimedOut, .transportUnavailable),
            (.staleData, .transportUnavailable), (.closedUnexpectedly, .transportUnavailable),
            (.closedByServer(code: 1000), .closedByServer), (.handshakeFailed, .closedByServer),
            (.decodingFailed, .decodingFailed), (.cancelled, .cancelled),
        ]
        for (wireFailure, expected) in cases {
            let transport = LifecycleFeed()
            let adapter = EchoPriceFeed(transport: transport, logging: LifecycleLogging())
            let stream = await adapter.events()
            var received: FeedFailure?
            let consumer = Task {
                for await event in stream {
                    if case let .connection(.failed(reason)) = event { received = reason }
                }
            }
            await adapter.start()
            await transport.emit(.transportFailure(wireFailure))
            try await eventually { received != nil }
            await consumer.value
            XCTAssertEqual(received, expected, "Failure: \(wireFailure)")
            await adapter.stop()
        }
    }

    func testConnectionResetsPreviousRetryAttempt() async throws {
        let transport = LifecycleFeed()
        let adapter = EchoPriceFeed(transport: transport, logging: LifecycleLogging())
        let stream = await adapter.events()
        var states: [FeedConnectionState] = []
        let consumer = Task {
            for await event in stream {
                if case let .connection(state) = event { states.append(state) }
            }
        }
        await transport.emit(.reconnectScheduled(attempt: 4))
        await transport.emit(.connected)
        await transport.emit(.disconnected(userInitiated: false))
        try await eventually { states.count == 3 }
        XCTAssertEqual(states, [.reconnecting(attempt: 4), .connected, .reconnecting(attempt: 0)])
        await adapter.stop()
        await consumer.value
    }
}
