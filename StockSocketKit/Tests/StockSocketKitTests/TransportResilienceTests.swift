//
//  TransportResilienceTests.swift
//  StockSocketKit
//
//  Created by Muhammad Ali Maniar on 18/10/2026.
//

import XCTest
@testable import StockSocketKit

final class TransportResilienceTests: XCTestCase {
    private func makeSession(
        _ sockets: [ScriptedSocket],
        health: EchoHealthPolicy = EchoHealthPolicy(),
        metrics: EchoTransportMetrics? = nil
    ) -> EchoWebSocketSession {
        let queue = SocketQueue(sockets)
        return EchoWebSocketSession(
            symbols: ["AAPL"],
            backoffPolicy: fastBackoff,
            healthPolicy: health,
            transportMetrics: metrics,
            connectionBuilder: { await queue.next() }
        )
    }

    // MARK: Stale-data watchdog

    func testSilentButAliveLinkIsReplacedByStaleDataWatchdog() async {
        let staleFired = expectation(description: "Stale metric fired")
        staleFired.assertForOverFulfill = false
        let session = makeSession(
            [ScriptedSocket(), ScriptedSocket()],
            health: EchoHealthPolicy(staleDataTimeoutNanoseconds: 40_000_000),
            metrics: EchoTransportMetrics(onStaleData: { staleFired.fulfill() })
        )
        let connected = expectation(description: "Reconnected after silence")
        connected.expectedFulfillmentCount = 2
        let stream = await session.wireEventsStream(bufferingPolicy: .unbounded)
        let reader = Task { for await event in stream where event == .connected { connected.fulfill() } }
        await session.start()
        await fulfillment(of: [connected, staleFired], timeout: 2)
        let diagnostics = await session.diagnostics()
        XCTAssertGreaterThanOrEqual(diagnostics.staleDataReconnects, 1)
        await session.stop()
        await reader.value
    }

    func testFlowingDataKeepsTheLinkAlive() async {
        let socket = ScriptedSocket()
        let session = makeSession([socket], health: EchoHealthPolicy(staleDataTimeoutNanoseconds: 150_000_000))
        let stream = await session.wireEventsStream(bufferingPolicy: .unbounded)
        let reader = Task { () -> Int in
            var reconnects = 0
            for await event in stream { if case .reconnectScheduled = event { reconnects += 1 } }
            return reconnects
        }
        await session.start()
        for _ in 0..<25 {
            await socket.deliver(validFrame())
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        await session.stop()
        let reconnects = await reader.value
        XCTAssertEqual(reconnects, 0)
    }

    func testSuspendedSessionIsNotTreatedAsStale() async {
        let session = makeSession([ScriptedSocket()], health: EchoHealthPolicy(staleDataTimeoutNanoseconds: 30_000_000))
        await session.setOutboundSuspended(true)
        let reconnect = expectation(description: "No reconnect while suspended")
        reconnect.isInverted = true
        let stream = await session.wireEventsStream(bufferingPolicy: .unbounded)
        let reader = Task { for await event in stream { if case .reconnectScheduled = event { reconnect.fulfill() } } }
        await session.start()
        await fulfillment(of: [reconnect], timeout: 0.3)
        await session.stop()
        await reader.value
    }

    // MARK: Lenient decoding

    func testBadFrameIsDroppedAndFeedContinues() async {
        let socket = ScriptedSocket()
        let dropped = expectation(description: "Drop metric fired")
        let session = makeSession([socket], metrics: EchoTransportMetrics(onFrameDropped: { dropped.fulfill() }))
        let good = expectation(description: "Valid frame after bad frame")
        let stream = await session.wireEventsStream(bufferingPolicy: .unbounded)
        let reader = Task {
            for await event in stream {
                if event == .connected {
                    await socket.deliver("garbage")
                    await socket.deliver(validFrame())
                }
                if case .decodedBatch = event { good.fulfill() }
                if case .transportFailure = event { XCTFail("One bad frame must not end the feed") }
            }
        }
        await session.start()
        await fulfillment(of: [dropped, good], timeout: 1)
        let diagnostics = await session.diagnostics()
        XCTAssertEqual(diagnostics.framesDropped, 1)
        XCTAssertEqual(diagnostics.framesDecoded, 1)
        await session.stop()
        await reader.value
    }

    func testGoodFrameResetsTheBadFrameStreak() async {
        let socket = ScriptedSocket()
        let limit = EchoHealthPolicy().maxConsecutiveDecodeFailures
        let session = makeSession([socket])
        let stream = await session.wireEventsStream(bufferingPolicy: .unbounded)
        let reader = Task {
            for await event in stream {
                if case .transportFailure = event { XCTFail("Streak should have been reset by the good frame") }
            }
        }
        await session.start()
        for _ in 0..<(limit - 1) { await socket.deliver("bad") }
        await socket.deliver(validFrame())
        for _ in 0..<(limit - 1) { await socket.deliver("bad") }
        await eventually { await session.diagnostics().framesDropped == 2 * (limit - 1) }
        await session.stop()
        await reader.value
    }

    func testSnapshotArrayAndLegacyObjectBothDecode() async {
        let socket = ScriptedSocket()
        let session = makeSession([socket])
        let stream = await session.wireEventsStream(bufferingPolicy: .unbounded)
        let reader = Task { () -> [Int] in
            var sizes: [Int] = []
            for await event in stream {
                if event == .connected {
                    await socket.deliver(snapshotFrame(symbols: ["AAA", "BBB", "CCC"]))
                    await socket.deliver(validFrame())
                }
                if case let .decodedBatch(batch) = event {
                    sizes.append(batch.count)
                    if sizes.count == 2 { break }
                }
            }
            return sizes
        }
        await session.start()
        let sizes = await reader.value
        XCTAssertEqual(sizes, [3, 1])
        await session.stop()
    }

    // MARK: Backpressure

    func testFullEventBufferIsCountedNotSilent() async {
        let socket = ScriptedSocket()
        let dropped = expectation(description: "Dropped-event metric fired")
        dropped.assertForOverFulfill = false
        let session = makeSession([socket], metrics: EchoTransportMetrics(onEventDropped: { _ in dropped.fulfill() }))
        // Held but never read: a consumer that has stalled.
        let stalledStream = await session.wireEventsStream(bufferingPolicy: .bufferingOldest(1))
        await session.start()
        for _ in 0..<5 { await socket.deliver(validFrame()) }
        await eventually { await session.diagnostics().framesDecoded == 5 }
        await fulfillment(of: [dropped], timeout: 1)
        let diagnostics = await session.diagnostics()
        XCTAssertGreaterThanOrEqual(diagnostics.eventsDropped, 1)
        await session.stop()
        withExtendedLifetime(stalledStream) {}
    }

    // MARK: Observability

    func testTimeToFirstTickIsReported() async {
        let socket = ScriptedSocket()
        let reported = expectation(description: "Time to first tick reported")
        let session = makeSession([socket], metrics: EchoTransportMetrics(onTimeToFirstTick: { ms in
            XCTAssertGreaterThanOrEqual(ms, 0)
            reported.fulfill()
        }))
        let stream = await session.wireEventsStream(bufferingPolicy: .unbounded)
        let reader = Task { for await event in stream where event == .connected { await socket.deliver(validFrame()) } }
        await session.start()
        await fulfillment(of: [reported], timeout: 1)
        let diagnostics = await session.diagnostics()
        XCTAssertNotNil(diagnostics.lastTimeToFirstTickMilliseconds)
        await session.stop()
        await reader.value
    }

    // MARK: Generator

    func testGeneratorEmitsOneEntryPerSymbolEverySnapshot() {
        var generator = SyntheticPriceGenerator(symbols: ["A", "B", "C"], nextUnit: { 0.5 })
        let snapshot = generator.makeSnapshot(emittedAtEpoch: 42)
        XCTAssertEqual(snapshot.map(\.symbol), ["A", "B", "C"])
        XCTAssertTrue(snapshot.allSatisfy { $0.emittedAtEpoch == 42 })
        XCTAssertEqual(snapshot[0].price, 487.5, accuracy: 0.0001)
        XCTAssertEqual(snapshot[0].previousClose, 487.5, accuracy: 0.0001)
    }

    func testGeneratorWalksFromThePreviousPriceAndKeepsAFixedReference() {
        var generator = SyntheticPriceGenerator(symbols: ["A"], nextUnit: { 1 })
        let first = generator.makeSnapshot(emittedAtEpoch: 1)[0]
        let second = generator.makeSnapshot(emittedAtEpoch: 2)[0]
        XCTAssertEqual(second.price - first.price, 6, accuracy: 0.0001)
        XCTAssertEqual(second.previousClose, first.previousClose, accuracy: 0.0001)
    }

    func testGeneratorNeverDropsBelowThePriceFloor() {
        var generator = SyntheticPriceGenerator(symbols: ["A"], nextUnit: { 0 })
        var last = 0.0
        for index in 0..<40 { last = generator.makeSnapshot(emittedAtEpoch: TimeInterval(index))[0].price }
        XCTAssertEqual(last, SyntheticPriceGenerator.minimumPrice)
    }

    func testGeneratorWithNoSymbolsProducesEmptySnapshot() {
        var generator = SyntheticPriceGenerator(symbols: [])
        XCTAssertTrue(generator.makeSnapshot(emittedAtEpoch: 0).isEmpty)
    }
}
