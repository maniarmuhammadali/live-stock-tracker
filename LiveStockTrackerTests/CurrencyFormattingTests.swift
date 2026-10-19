//
//  CurrencyFormattingTests.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import XCTest
@testable import LiveStockTracker

@MainActor
final class CurrencyFormattingTests: XCTestCase {
    func testUSDUsesGermanSeparatorsWithoutChangingDenomination() {
        let text = CurrencyFormatting.currencyString(for: 1234.5, locale: Locale(identifier: "de_DE"))
        XCTAssertEqual(text, "1.234,50 $")
    }

    func testSignedPercentUsesLocalizedSpacingAndScale() {
        XCTAssertEqual(CurrencyFormatting.signedPercentString(for: 12.5, locale: Locale(identifier: "de_DE")), "+12,50 %")
        XCTAssertEqual(CurrencyFormatting.signedPercentString(for: -12.5, locale: Locale(identifier: "en_US")), "-12.50%")
        XCTAssertEqual(CurrencyFormatting.signedPercentString(for: 0, locale: Locale(identifier: "en_US")), "0.00%")
    }

    func testArabicUsesLocalizedDigitsAndPercentSymbol() {
        let locale = Locale(identifier: "ar_EG")
        let currency = CurrencyFormatting.currencyString(for: 1234.5, locale: locale)
        let percent = CurrencyFormatting.signedPercentString(for: -12.5, locale: locale)
        XCTAssertTrue(currency.contains("١٬٢٣٤٫٥٠"), currency)
        XCTAssertTrue(currency.contains("US$"), currency)
        XCTAssertTrue(percent.contains("١٢٫٥٠"), percent)
        XCTAssertTrue(percent.contains("٪"), percent)
        XCTAssertFalse(percent.contains("%"), percent)
    }
}
