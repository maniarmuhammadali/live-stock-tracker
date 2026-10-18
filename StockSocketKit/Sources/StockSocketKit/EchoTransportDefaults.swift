//
//  EchoTransportDefaults.swift
//  StockSocketKit
//
//  Created by Muhammad Ali Maniar on 18/10/2026.
//

import Foundation

public enum EchoTransportDefaults {
    public static let outboundIntervalNanoseconds: UInt64 = 1_000_000_000
    public static let handshakeTimeoutNanoseconds: UInt64 = 30_000_000_000
    public static let backoffInitialNanoseconds: UInt64 = 250_000_000
    public static let backoffMultiplier = 1.75
    public static let backoffMaxNanoseconds: UInt64 = 8_000_000_000
}

extension ExponentialBackoffPolicy {
    public static let standard = ExponentialBackoffPolicy(
        initialNanoseconds: EchoTransportDefaults.backoffInitialNanoseconds,
        multiplier: EchoTransportDefaults.backoffMultiplier,
        maxNanoseconds: EchoTransportDefaults.backoffMaxNanoseconds,
        jitter: .full
    )
}
