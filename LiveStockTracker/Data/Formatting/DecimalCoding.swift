//
//  DecimalCoding.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import Foundation

enum DecimalCoding {
    nonisolated static func encode(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }

    nonisolated static func decode(_ string: String) -> Decimal? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return nil
        }

        return Decimal(string: trimmed, locale: Locale(identifier: "en_US_POSIX"))
    }
}
