//
//  SortOption.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 18/10/2026.
//

import Foundation

nonisolated enum SortField: String, CaseIterable, Sendable, Identifiable {
    case price
    case priceChange

    var id: String { rawValue }
}

nonisolated enum SortDirection: String, CaseIterable, Sendable, Identifiable {
    case ascending
    case descending

    var id: String { rawValue }
}

nonisolated struct SortOption: Hashable, Sendable {
    var field: SortField
    var direction: SortDirection

    static let `default` = SortOption(field: .price, direction: .descending)
}

extension Array where Element == StockQuote {
    /// Equal keys fall back to the symbol (always A to Z), so the order is total and rows never swap places
    /// just because two prices tied.
    nonisolated func sorted(by option: SortOption) -> [StockQuote] {
        sorted { lhs, rhs in
            let (left, right) = (option.field.key(of: lhs), option.field.key(of: rhs))
            if left != right {
                return option.direction == .ascending ? left < right : left > right
            }
            return lhs.symbol < rhs.symbol
        }
    }
}

private extension SortField {
    nonisolated func key(of quote: StockQuote) -> Decimal {
        switch self {
        case .price: return quote.price
        case .priceChange: return quote.dayChange
        }
    }
}
