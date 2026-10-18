//
//  WebSocketPolicyTests.swift
//  StockSocketKit
//
//  Created by Muhammad Ali Maniar on 18/10/2026.
//

import XCTest
@testable import StockSocketKit

final class WebSocketPolicyTests: XCTestCase {
    func testFullJitterSpansZeroToExponentiallyCappedDelay() {
        let policy = ExponentialBackoffPolicy(initialNanoseconds: 100, multiplier: 2, maxNanoseconds: 800, jitter: .full)
        XCTAssertEqual(policy.delayNanoseconds(forAttempt: 0, randomUnit: 0), 0)
        XCTAssertEqual(policy.delayNanoseconds(forAttempt: 0, randomUnit: 1), 100)
        XCTAssertEqual(policy.delayNanoseconds(forAttempt: 2, randomUnit: 0.5), 200)
        XCTAssertEqual(policy.delayNanoseconds(forAttempt: 100_000, randomUnit: 1), 800)
        XCTAssertEqual(policy.delayNanoseconds(forAttempt: -1, randomUnit: 1), 100)
    }

    func testBackoffConversionHandlesUInt64Boundary() {
        let policy = ExponentialBackoffPolicy(initialNanoseconds: UInt64.max, multiplier: 2,
                                              maxNanoseconds: UInt64.max, jitter: .none)
        XCTAssertEqual(policy.delayNanoseconds(forAttempt: Int.max, randomUnit: 1), UInt64.max)
    }

    func testClosurePolicyDistinguishesTransientAndTerminalCodes() {
        for code in [1001, 1005, 1006, 1011, 1012, 1013] {
            XCTAssertTrue(WebSocketClose(code: code, reason: nil).shouldRetry, "\(code)")
        }
        for code in [1000, 1002, 1003, 1007, 1008, 1009, 1010, 1015, 4001] {
            XCTAssertFalse(WebSocketClose(code: code, reason: nil).shouldRetry, "\(code)")
        }
    }

    func testReservedObservationCodesAreNeverSentInCloseFrames() {
        for code in [0, 1005, 1006, 1015] {
            XCTAssertEqual(WebSocketClose(code: code, reason: nil).responseCode, .goingAway)
        }
        XCTAssertEqual(WebSocketClose(code: 1008, reason: nil).responseCode, .policyViolation)
    }
}
