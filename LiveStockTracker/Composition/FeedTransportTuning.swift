//
//  FeedTransportTuning.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import Foundation
import StockSocketKit

/// Every timing and policy knob of the feed transport in one value.
/// Defaults come from `EchoTransportDefaults` in StockSocketKit (the single source of truth).
/// A bundled `FeedTransportTuning.json`, or any `Data` such as remote config, may override any subset.
/// Values are clamped so a bad config can slow the feed but never crash the app.
nonisolated struct FeedTransportTuning: Equatable, Sendable, Decodable {
    var outboundIntervalMilliseconds = Self.milliseconds(EchoTransportDefaults.outboundIntervalNanoseconds)
    var handshakeTimeoutMilliseconds = Self.milliseconds(EchoTransportDefaults.handshakeTimeoutNanoseconds)
    var heartbeatIntervalMilliseconds = Self.milliseconds(EchoTransportDefaults.heartbeatIntervalNanoseconds)
    var pongTimeoutMilliseconds = Self.milliseconds(EchoTransportDefaults.pongTimeoutNanoseconds)
    var sendTimeoutMilliseconds = Self.milliseconds(EchoTransportDefaults.sendTimeoutNanoseconds)
    var staleDataTimeoutMilliseconds = Self.milliseconds(EchoTransportDefaults.staleDataTimeoutNanoseconds)
    var maxConsecutiveDecodeFailures = EchoTransportDefaults.maxConsecutiveDecodeFailures
    var backoffInitialMilliseconds = Self.milliseconds(EchoTransportDefaults.backoffInitialNanoseconds)
    var backoffMultiplier = EchoTransportDefaults.backoffMultiplier
    var backoffMaxMilliseconds = Self.milliseconds(EchoTransportDefaults.backoffMaxNanoseconds)

    static let defaults = FeedTransportTuning()
    static let resourceName = "FeedTransportTuning"

    init() {}

    private enum CodingKeys: String, CodingKey {
        case outboundIntervalMilliseconds, handshakeTimeoutMilliseconds, heartbeatIntervalMilliseconds
        case pongTimeoutMilliseconds, sendTimeoutMilliseconds, staleDataTimeoutMilliseconds
        case maxConsecutiveDecodeFailures, backoffInitialMilliseconds, backoffMultiplier
        case backoffMaxMilliseconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let base = FeedTransportTuning()
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) throws -> T {
            try container.decodeIfPresent(T.self, forKey: key) ?? fallback
        }
        outboundIntervalMilliseconds = try value(.outboundIntervalMilliseconds, base.outboundIntervalMilliseconds)
        handshakeTimeoutMilliseconds = try value(.handshakeTimeoutMilliseconds, base.handshakeTimeoutMilliseconds)
        heartbeatIntervalMilliseconds = try value(.heartbeatIntervalMilliseconds, base.heartbeatIntervalMilliseconds)
        pongTimeoutMilliseconds = try value(.pongTimeoutMilliseconds, base.pongTimeoutMilliseconds)
        sendTimeoutMilliseconds = try value(.sendTimeoutMilliseconds, base.sendTimeoutMilliseconds)
        staleDataTimeoutMilliseconds = try value(.staleDataTimeoutMilliseconds, base.staleDataTimeoutMilliseconds)
        maxConsecutiveDecodeFailures = try value(.maxConsecutiveDecodeFailures, base.maxConsecutiveDecodeFailures)
        backoffInitialMilliseconds = try value(.backoffInitialMilliseconds, base.backoffInitialMilliseconds)
        backoffMultiplier = try value(.backoffMultiplier, base.backoffMultiplier)
        backoffMaxMilliseconds = try value(.backoffMaxMilliseconds, base.backoffMaxMilliseconds)
    }

    static func load(from data: Data) -> FeedTransportTuning {
        (try? JSONDecoder().decode(FeedTransportTuning.self, from: data)) ?? .defaults
    }

    static func load(bundle: Bundle) -> FeedTransportTuning {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return .defaults
        }
        return load(from: data)
    }

    // MARK: Derived transport values (clamped)

    var outboundIntervalNanoseconds: UInt64 { Self.nanoseconds(outboundIntervalMilliseconds, floor: 50) }
    var handshakeTimeoutNanoseconds: UInt64 { Self.nanoseconds(handshakeTimeoutMilliseconds, floor: 1_000) }

    var healthPolicy: EchoHealthPolicy {
        EchoHealthPolicy(
            heartbeatIntervalNanoseconds: Self.nanoseconds(heartbeatIntervalMilliseconds, floor: 1_000),
            pongTimeoutNanoseconds: Self.nanoseconds(pongTimeoutMilliseconds, floor: 500),
            sendTimeoutNanoseconds: Self.nanoseconds(sendTimeoutMilliseconds, floor: 500),
            staleDataTimeoutNanoseconds: Self.nanoseconds(staleDataTimeoutMilliseconds, floor: 1_000),
            maxConsecutiveDecodeFailures: max(1, maxConsecutiveDecodeFailures)
        )
    }

    var backoffPolicy: ExponentialBackoffPolicy {
        let initial = Self.nanoseconds(backoffInitialMilliseconds, floor: 10)
        return ExponentialBackoffPolicy(
            initialNanoseconds: initial,
            multiplier: backoffMultiplier.isFinite ? max(1, backoffMultiplier) : 1,
            maxNanoseconds: max(initial, Self.nanoseconds(backoffMaxMilliseconds, floor: 10)),
            jitter: .full
        )
    }

    private static func milliseconds(_ nanoseconds: UInt64) -> Int {
        Int(nanoseconds / 1_000_000)
    }

    private static func nanoseconds(_ milliseconds: Int, floor: Int) -> UInt64 {
        UInt64(max(milliseconds, floor)) * 1_000_000
    }
}
