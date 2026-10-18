//
//  PersistedQuoteAccess.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import Foundation
import SwiftData

/// SwiftData read helpers for persisted quote rows.
nonisolated enum PersistedQuoteAccess {
    static func quotesPage(context: ModelContext, limit: Int, cursor: String?) throws -> QuotesPage {
        guard limit > 0 else {
            return QuotesPage(quotes: [], nextCursor: nil)
        }

        let fetchLimit = limit + 1

        let rows: [PersistedQuote]
        if let cursor, cursor.isEmpty == false {
            let afterSymbol = cursor
            let predicate = #Predicate<PersistedQuote> { persisted in
                persisted.symbol > afterSymbol
            }
            var descriptor = FetchDescriptor<PersistedQuote>(
                predicate: predicate,
                sortBy: [SortDescriptor(\PersistedQuote.symbol)]
            )
            descriptor.fetchLimit = fetchLimit
            rows = try context.fetch(descriptor)
        } else {
            var descriptor = FetchDescriptor<PersistedQuote>(
                sortBy: [SortDescriptor(\PersistedQuote.symbol)]
            )
            descriptor.fetchLimit = fetchLimit
            rows = try context.fetch(descriptor)
        }

        let hasAnotherPage = rows.count > limit
        let pageRows = Array(rows.prefix(limit))

        let quotes = decodedQuotes(from: pageRows)
        let nextCursor = hasAnotherPage ? pageRows.last?.symbol : nil
        return QuotesPage(quotes: quotes, nextCursor: nextCursor)
    }

    static func hasAnyQuotes(context: ModelContext) throws -> Bool {
        let descriptor = FetchDescriptor<PersistedQuote>()
        return try context.fetchCount(descriptor) > 0
    }

    /// Build an in-memory map from every persisted row, skipping malformed numerics.
    static func quotesBySymbol(context: ModelContext) throws -> [String: StockQuote] {
        let descriptor = FetchDescriptor<PersistedQuote>()
        let rows = try context.fetch(descriptor)
        var accumulator: [String: StockQuote] = [:]
        accumulator.reserveCapacity(rows.count)

        for row in rows {
            guard let price = DecimalCoding.decode(row.priceString) else {
                continue
            }
            guard let previousClose = DecimalCoding.decode(row.previousCloseString) else {
                continue
            }

            accumulator[row.symbol] = StockQuote(
                symbol: row.symbol,
                price: price,
                previousClose: previousClose,
                updatedAt: row.updatedAt
            )
        }

        return accumulator
    }

    private static func decodedQuotes(from rows: [PersistedQuote]) -> [StockQuote] {
        var quotes: [StockQuote] = []
        quotes.reserveCapacity(rows.count)

        for row in rows {
            guard let price = DecimalCoding.decode(row.priceString) else {
                continue
            }
            guard let previousClose = DecimalCoding.decode(row.previousCloseString) else {
                continue
            }

            quotes.append(
                StockQuote(symbol: row.symbol, price: price, previousClose: previousClose, updatedAt: row.updatedAt)
            )
        }

        return quotes
    }
}
