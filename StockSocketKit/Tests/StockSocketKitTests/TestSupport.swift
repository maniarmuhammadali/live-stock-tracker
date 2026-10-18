//
//  TestSupport.swift
//  StockSocketKit
//
//  Created by Muhammad Ali Maniar on 18/10/2026.
//

import XCTest
@testable import StockSocketKit

/// Polls an async condition; fails the test (and returns false) if it never holds.
@discardableResult
func eventually(
    timeout: TimeInterval = 2,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ condition: () async -> Bool
) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if await condition() { return true }
        try? await Task.sleep(nanoseconds: 5_000_000)
    }
    XCTFail("Condition not met within \(timeout)s", file: file, line: line)
    return false
}

let fastBackoff = ExponentialBackoffPolicy(initialNanoseconds: 1_000_000, multiplier: 2, maxNanoseconds: 8_000_000, jitter: .none)

func validFrame(symbol: String = "AAPL", price: Double = 125) -> String {
    "{\"symbol\":\"\(symbol)\",\"price\":\(price),\"previousClose\":100,\"emittedAtEpoch\":1}"
}

func snapshotFrame(symbols: [String]) -> String {
    "[" + symbols.map { validFrame(symbol: $0) }.joined(separator: ",") + "]"
}
