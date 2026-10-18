//
//  EchoStockPayload.swift
//  StockSocketKit
//
//  Created by Muhammad Ali Maniar on 01/05/2026.
//

import Foundation

public struct EchoStockPayload: Codable, Equatable, Sendable {
    public let symbol: String
    public let price: Double
    public let previousClose: Double
    public let emittedAtEpoch: TimeInterval

    public init(symbol: String, price: Double, previousClose: Double, emittedAtEpoch: TimeInterval) {
        self.symbol = symbol
        self.price = price
        self.previousClose = previousClose
        self.emittedAtEpoch = emittedAtEpoch
    }
}
