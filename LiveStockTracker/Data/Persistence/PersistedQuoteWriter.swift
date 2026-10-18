//
//  PersistedQuoteWriter.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import Foundation
import SwiftData

nonisolated enum PersistedQuoteWriter {
    static func upsert(quote: StockQuote, context: ModelContext) throws {
        try applyUpsert(quote: quote, context: context)
        try context.save()
    }

    static func upsertBatch(quotes: [StockQuote], context: ModelContext) throws {
        guard quotes.isEmpty == false else {
            return
        }
        for quote in quotes {
            try applyUpsert(quote: quote, context: context)
        }
        try context.save()
    }

    private static func applyUpsert(quote: StockQuote, context: ModelContext) throws {
        let symbol = quote.symbol
        let predicate = #Predicate<PersistedQuote> { persisted in
            persisted.symbol == symbol
        }

        var descriptor = FetchDescriptor<PersistedQuote>(predicate: predicate)
        descriptor.fetchLimit = 1
        let existing = try context.fetch(descriptor).first

        let priceString = DecimalCoding.encode(quote.price)
        let previousString = DecimalCoding.encode(quote.previousClose)

        if let existing {
            existing.priceString = priceString
            existing.previousCloseString = previousString
            existing.updatedAt = quote.updatedAt
        } else {
            context.insert(
                PersistedQuote(
                    symbol: symbol,
                    priceString: priceString,
                    previousCloseString: previousString,
                    updatedAt: quote.updatedAt
                )
            )
        }
    }
}
