//
//  DomainQuoteMappingTests.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import StockSocketKit
import XCTest

@testable import LiveStockTracker

final class DomainQuoteMappingTests: XCTestCase {
    func testMappingRejectsEmptySymbol() {
        let payload = EchoStockPayload(symbol: "", price: 1, previousClose: 1, emittedAtEpoch: 0)
        XCTAssertNil(DomainQuoteMapping.quote(from: payload))
    }

    func testMappingUppercasesSymbol() {
        let payload = EchoStockPayload(symbol: "xyz", price: 10.5, previousClose: 10, emittedAtEpoch: 1_700_000_000)
        let quote = DomainQuoteMapping.quote(from: payload)
        XCTAssertEqual(quote?.symbol, "XYZ")
    }
}
