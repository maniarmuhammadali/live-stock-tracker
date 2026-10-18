//
//  DomainTests.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 18/10/2026.
//

@testable import LiveStockTracker
import XCTest

final class DomainTests: XCTestCase {
    func testTwoFieldsWithTwoDirectionsGiveFourOrderings() {
        XCTAssertEqual(SortField.allCases, [.price, .priceChange])
        XCTAssertEqual(SortDirection.allCases, [.ascending, .descending])
        let orderings = SortField.allCases.flatMap { field in
            SortDirection.allCases.map { SortOption(field: field, direction: $0) }
        }
        XCTAssertEqual(Set(orderings).count, 4)
        XCTAssertEqual(SortOption.default, SortOption(field: .price, direction: .descending))
    }

    private func quote(_ symbol: String, price: Decimal, previousClose: Decimal = 100) -> StockQuote {
        StockQuote(symbol: symbol, price: price, previousClose: previousClose, updatedAt: Date(timeIntervalSince1970: 1))
    }

    func testTiedValuesOrderBySymbolInBothDirections() {
        let quotes = [quote("CCC", price: 50), quote("AAA", price: 50), quote("BBB", price: 50)]
        for direction in SortDirection.allCases {
            let sorted = quotes.sorted(by: SortOption(field: .price, direction: direction))
            XCTAssertEqual(sorted.map(\.symbol), ["AAA", "BBB", "CCC"], "\(direction)")
        }
    }

    func testOrderIsIndependentOfInputOrder() {
        let quotes = [quote("A", price: 10), quote("B", price: 30), quote("C", price: 20), quote("D", price: 30)]
        let option = SortOption(field: .price, direction: .descending)
        let expected = ["B", "D", "C", "A"]
        XCTAssertEqual(quotes.sorted(by: option).map(\.symbol), expected)
        XCTAssertEqual(quotes.reversed().sorted(by: option).map(\.symbol), expected)
        XCTAssertEqual(quotes.shuffled().sorted(by: option).map(\.symbol), expected)
    }

    func testPriceChangeUsesDayChangeNotPrice() {
        let quotes = [quote("A", price: 500, previousClose: 499), quote("B", price: 10, previousClose: 5)]
        XCTAssertEqual(quotes.sorted(by: SortOption(field: .priceChange, direction: .descending)).map(\.symbol), ["B", "A"])
        XCTAssertEqual(quotes.sorted(by: SortOption(field: .priceChange, direction: .ascending)).map(\.symbol), ["A", "B"])
        XCTAssertEqual(quotes.sorted(by: SortOption(field: .price, direction: .descending)).map(\.symbol), ["A", "B"])
    }

    func testQuoteDerivedMovementMatchesExpectation() {
        let quote = StockQuote(symbol: "AAA", price: 110, previousClose: 100, updatedAt: Date(timeIntervalSince1970: 1))

        XCTAssertEqual(quote.dayChange, 10)
        XCTAssertEqual(NSDecimalNumber(decimal: quote.dayChangePercent).doubleValue, 10, accuracy: 0.0001)
    }
}
