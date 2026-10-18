//
//  WireDecoderTests.swift
//  StockSocketKit
//
//  Created by Muhammad Ali Maniar on 18/10/2026.
//

import XCTest
@testable import StockSocketKit

final class WireDecoderTests: XCTestCase {
    func testWireDecoderAcceptsArrayAndObjectButNotGarbage() {
        let decoder = JSONDecoder()
        XCTAssertEqual(EchoWireDecoder.decode(Data(snapshotFrame(symbols: ["A", "B"]).utf8), using: decoder)?.count, 2)
        XCTAssertEqual(EchoWireDecoder.decode(Data(validFrame().utf8), using: decoder)?.count, 1)
        XCTAssertEqual(EchoWireDecoder.decode(Data("[]".utf8), using: decoder)?.count, 0)
        XCTAssertNil(EchoWireDecoder.decode(Data("{\"symbol\":1}".utf8), using: decoder))
        XCTAssertNil(EchoWireDecoder.decode(Data("nope".utf8), using: decoder))
    }

    func testEchoPayloadRoundTrip() throws {
        let payload = EchoStockPayload(symbol: "AAPL", price: 123.45, previousClose: 120.10, emittedAtEpoch: 1_700_000_000)
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(EchoStockPayload.self, from: data)

        XCTAssertEqual(decoded.symbol, payload.symbol)
        XCTAssertEqual(decoded.price, payload.price, accuracy: 0.0001)
        XCTAssertEqual(decoded.previousClose, payload.previousClose, accuracy: 0.0001)
        XCTAssertEqual(decoded.emittedAtEpoch, payload.emittedAtEpoch, accuracy: 0.0001)
    }
}
