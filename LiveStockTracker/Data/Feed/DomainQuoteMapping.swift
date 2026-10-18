//
//  DomainQuoteMapping.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import Foundation
import StockSocketKit

enum DomainQuoteMapping {
    nonisolated static func quote(from payload: EchoStockPayload) -> StockQuote? {
        guard payload.symbol.isEmpty == false else {
            return nil
        }

        guard let priceDecimal = DecimalCoding.decode("\(payload.price)") else {
            return nil
        }

        guard let previousDecimal = DecimalCoding.decode("\(payload.previousClose)") else {
            return nil
        }

        let updatedAt = Date(timeIntervalSince1970: payload.emittedAtEpoch)

        return StockQuote(symbol: payload.symbol.uppercased(), price: priceDecimal, previousClose: previousDecimal, updatedAt: updatedAt)
    }
}
