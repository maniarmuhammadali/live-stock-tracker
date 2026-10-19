//
//  FeedTransportTuningTests.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import StockSocketKit
import XCTest
@testable import LiveStockTracker

final class FeedTransportTuningTests: XCTestCase {
    func testMissingOrGarbageConfigFallsBackToDefaults() {
        XCTAssertEqual(FeedTransportTuning.load(from: Data("{}".utf8)), .defaults)
        XCTAssertEqual(FeedTransportTuning.load(from: Data("not json".utf8)), .defaults)
        XCTAssertEqual(FeedTransportTuning.load(bundle: Bundle(for: FeedTransportTuningTests.self)), .defaults)
    }

    func testPartialConfigOverridesOnlyTheNamedKeys() {
        let json = "{\"staleDataTimeoutMilliseconds\":4000,\"backoffMultiplier\":2}"
        let tuning = FeedTransportTuning.load(from: Data(json.utf8))
        XCTAssertEqual(tuning.staleDataTimeoutMilliseconds, 4_000)
        XCTAssertEqual(tuning.backoffMultiplier, 2)
        XCTAssertEqual(tuning.heartbeatIntervalMilliseconds, FeedTransportTuning.defaults.heartbeatIntervalMilliseconds)
        XCTAssertEqual(tuning.healthPolicy.staleDataTimeoutNanoseconds, 4_000_000_000)
    }

    func testHostileValuesAreClampedInsteadOfTrapping() {
        let json = """
        {"outboundIntervalMilliseconds":-5,"heartbeatIntervalMilliseconds":0,"pongTimeoutMilliseconds":0,
         "sendTimeoutMilliseconds":-1,"staleDataTimeoutMilliseconds":0,"maxConsecutiveDecodeFailures":0,
         "backoffInitialMilliseconds":9000,"backoffMultiplier":0.1,"backoffMaxMilliseconds":10}
        """
        let tuning = FeedTransportTuning.load(from: Data(json.utf8))
        XCTAssertGreaterThan(tuning.outboundIntervalNanoseconds, 0)
        XCTAssertGreaterThan(tuning.healthPolicy.staleDataTimeoutNanoseconds, 0)
        XCTAssertEqual(tuning.healthPolicy.maxConsecutiveDecodeFailures, 1)
        XCTAssertGreaterThanOrEqual(tuning.backoffPolicy.maxNanoseconds, tuning.backoffPolicy.initialNanoseconds)
        XCTAssertGreaterThanOrEqual(tuning.backoffPolicy.multiplier, 1)
    }

    func testDefaultsAreDerivedFromTheKitsSingleSourceOfTruth() {
        let tuning = FeedTransportTuning.defaults
        XCTAssertEqual(tuning.healthPolicy, EchoHealthPolicy())
        XCTAssertEqual(tuning.outboundIntervalNanoseconds, EchoTransportDefaults.outboundIntervalNanoseconds)
        XCTAssertEqual(tuning.handshakeTimeoutNanoseconds, EchoTransportDefaults.handshakeTimeoutNanoseconds)
        XCTAssertEqual(tuning.backoffPolicy.initialNanoseconds, ExponentialBackoffPolicy.standard.initialNanoseconds)
        XCTAssertEqual(tuning.backoffPolicy.maxNanoseconds, ExponentialBackoffPolicy.standard.maxNanoseconds)
        XCTAssertEqual(tuning.backoffPolicy.multiplier, ExponentialBackoffPolicy.standard.multiplier)
    }

    func testShippedConfigAddsNoUnintendedOverrides() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("LiveStockTracker/Resources/FeedTransportTuning.json")
        XCTAssertEqual(FeedTransportTuning.load(from: try Data(contentsOf: url)), .defaults)
    }
}
