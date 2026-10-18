//
//  LiveEchoSmokeTests.swift
//  StockSocketKit
//
//  Created by Muhammad Ali Maniar on 01/05/2026.
//

import XCTest
import StockSocketKit

final class LiveEchoSmokeTests: XCTestCase {
    func testRealEchoServerRoundTripsASnapshot() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["STOCKSOCKET_LIVE_TESTS"] == "1",
                          "Set STOCKSOCKET_LIVE_TESTS=1 to hit ws.postman-echo.com")
        let symbols = ["AAPL", "NVDA", "GOOG"]
        let session = try EchoWebSocketSession(
            url: XCTUnwrap(URL(string: "wss://ws.postman-echo.com/raw")),
            symbols: symbols,
            outboundIntervalNanoseconds: 300_000_000,
            backoffPolicy: ExponentialBackoffPolicy(initialNanoseconds: 250_000_000, multiplier: 1.75,
                                                    maxNanoseconds: 4_000_000_000),
            logger: nil
        )
        let stream = await session.wireEventsStream()
        await session.start()
        let received = await withTaskGroup(of: [EchoStockPayload]?.self) { group in
            group.addTask {
                for await event in stream {
                    guard case let .decodedBatch(batch) = event else { continue }
                    return batch
                }
                return nil
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
        let diagnostics = await session.diagnostics()
        await session.stop()
        let batch = try XCTUnwrap(received, "No echoed snapshot within 20s")
        XCTAssertEqual(Set(batch.map(\.symbol)), Set(symbols))
        XCTAssertNotNil(diagnostics.lastTimeToFirstTickMilliseconds)
    }
}
