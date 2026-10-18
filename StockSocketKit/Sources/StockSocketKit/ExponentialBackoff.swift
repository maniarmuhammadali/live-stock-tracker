//
//  ExponentialBackoff.swift
//  StockSocketKit
//
//  Created by Muhammad Ali Maniar on 18/10/2026.
//

import Foundation

public struct ExponentialBackoffPolicy: Sendable {
    public enum Jitter: Sendable {
        case none
        case full
        case proportional(Double)
    }

    public let initialNanoseconds: UInt64
    public let multiplier: Double
    public let maxNanoseconds: UInt64
    public let jitter: Jitter

    public init(initialNanoseconds: UInt64, multiplier: Double, maxNanoseconds: UInt64, jitter: Jitter = .full) {
        precondition(multiplier.isFinite && multiplier >= 1)
        precondition(maxNanoseconds >= initialNanoseconds)
        if case let .proportional(ratio) = jitter { precondition(ratio.isFinite && (0...1).contains(ratio)) }
        self.initialNanoseconds = initialNanoseconds
        self.multiplier = multiplier
        self.maxNanoseconds = maxNanoseconds
        self.jitter = jitter
    }

    /// Compatibility for consumers that explicitly request proportional jitter.
    public init(initialNanoseconds: UInt64, multiplier: Double, maxNanoseconds: UInt64, jitterRatio: Double) {
        self.init(initialNanoseconds: initialNanoseconds, multiplier: multiplier, maxNanoseconds: maxNanoseconds,
                  jitter: jitterRatio == 0 ? .none : .proportional(jitterRatio))
    }

    public func delayNanoseconds(forAttempt attempt: Int) -> UInt64 {
        delayNanoseconds(forAttempt: attempt, randomUnit: Double.random(in: 0...1))
    }

    func delayNanoseconds(forAttempt attempt: Int, randomUnit: Double) -> UInt64 {
        precondition(randomUnit.isFinite && (0...1).contains(randomUnit))
        guard initialNanoseconds > 0 else { return 0 }
        let raw = Double(initialNanoseconds) * pow(multiplier, Double(max(0, attempt)))
        let cap = min(raw, Double(maxNanoseconds))
        let delay: Double
        switch jitter {
        case .none: delay = cap
        case .full: delay = cap * randomUnit
        case let .proportional(ratio): delay = min(Double(maxNanoseconds), max(0, cap * (1 + ratio * (2 * randomUnit - 1))))
        }
        // Double(UInt64.max) rounds to 2^64; avoid a trapping conversion at the boundary.
        return delay >= Double(UInt64.max) ? UInt64.max : UInt64(delay)
    }
}
