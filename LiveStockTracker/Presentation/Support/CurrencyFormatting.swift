//
//  CurrencyFormatting.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import Foundation

enum CurrencyFormatting {
    static func currencyString(for decimal: Decimal, locale: Locale = .autoupdatingCurrent) -> String {
        decimal.formatted(.currency(code: "USD").precision(.fractionLength(2)).locale(locale))
    }

    static func signedCurrencyString(for decimal: Decimal, locale: Locale = .autoupdatingCurrent) -> String {
        decimal.formatted(
            .currency(code: "USD")
                .precision(.fractionLength(2))
                .sign(strategy: .always(showZero: false))
                .locale(locale)
        )
    }

    static func signedPercentString(for decimal: Decimal, locale: Locale = .autoupdatingCurrent) -> String {
        (decimal / 100).formatted(
            .percent.precision(.fractionLength(2))
                .sign(strategy: .always(includingZero: false))
                .locale(locale)
        )
    }
}
