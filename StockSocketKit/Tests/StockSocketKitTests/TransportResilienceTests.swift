//
//  TransportResilienceTests.swift
//  StockSocketKit
//
//  Created by Muhammad Ali Maniar on 18/10/2026.
//

import XCTest
@testable import StockSocketKit

final class TransportResilienceTests: XCTestCase {
    private func makeSession(_ sockets: [ScriptedSocket]) -> EchoWebSocketSession {
        let queue = SocketQueue(sockets)
        return EchoWebSocketSession(
            symbols: ["AAPL"],
            backoffPolicy: fastBackoff,
            connectionBuilder: { await queue.next() }
        )
    }

    // MARK: Decoding

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
