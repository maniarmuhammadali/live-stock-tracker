//
//  SyntheticPriceGenerator.swift
//  StockSocketKit
//
//  Created by Muhammad Ali Maniar on 18/10/2026.
//

import Foundation

public struct SyntheticPriceGenerator: Sendable {
    public static let minimumPrice = 1.5

    private let symbols: [String]
    private let nextUnit: @Sendable () -> Double
    private var lastPrices: [String: Double] = [:]
    private var referenceCloses: [String: Double] = [:]

    public init(symbols: [String], nextUnit: @escaping @Sendable () -> Double = { Double.random(in: 0...1) }) {
        self.symbols = symbols
        self.nextUnit = nextUnit
    }

    public mutating func makeSnapshot(emittedAtEpoch: TimeInterval) -> [EchoStockPayload] {
        symbols.map { symbol in
            let prior = lastPrices[symbol] ?? 55 + 865 * nextUnit()
            let delta = -6 + 12 * nextUnit()
            let price = max(Self.minimumPrice, prior + delta)
            lastPrices[symbol] = price
            if referenceCloses[symbol] == nil {
                referenceCloses[symbol] = prior * (0.985 + 0.03 * nextUnit())
            }
            return EchoStockPayload(
                symbol: symbol,
                price: price,
                previousClose: referenceCloses[symbol] ?? prior,
                emittedAtEpoch: emittedAtEpoch
            )
        }
    }
}
