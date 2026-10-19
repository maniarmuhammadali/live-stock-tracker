//
//  ScreenModelBehaviourTests.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import XCTest
@testable import LiveStockTracker

@MainActor
final class ScreenModelBehaviourTests: XCTestCase {
    private func quote(_ symbol: String, price: Decimal, previousClose: Decimal = 100) -> StockQuote {
        StockQuote(symbol: symbol, price: price, previousClose: previousClose, updatedAt: Date(timeIntervalSince1970: 1))
    }

    private func makeModel(quotes: [StockQuote]) async -> (StocksListViewModel, MockStockRepository) {
        let repository = MockStockRepository()
        repository.catalogEntries = ["AAA", "BBB", "CCC", "DDD"].map {
            StockCatalogEntry(symbol: $0, companyName: $0, descriptionText: "D")
        }
        repository.hasPersistedQuotesValue = .success(true)
        repository.mergedQuotes = quotes
        let model = StocksListViewModel(repository: repository, feed: repository.controls)
        await model.activate()
        return (model, repository)
    }

    func testTiedPricesKeepAStableSymbolOrderInBothDirections() async {
        let (model, _) = await makeModel(quotes: [quote("CCC", price: 50), quote("AAA", price: 50), quote("BBB", price: 50)])
        for direction in SortDirection.allCases {
            model.sortOption = SortOption(field: .price, direction: direction)
            XCTAssertEqual(model.rows.map(\.symbol), ["AAA", "BBB", "CCC", "DDD"], "\(direction)")
        }
    }

    func testSymbolsStillWaitingForAPriceAlwaysTrailInAlphabeticalOrder() async {
        let (model, _) = await makeModel(quotes: [quote("CCC", price: 10), quote("AAA", price: 90)])
        model.sortOption = SortOption(field: .price, direction: .descending)
        XCTAssertEqual(model.rows.map(\.symbol), ["AAA", "CCC", "BBB", "DDD"])
        model.sortOption = SortOption(field: .price, direction: .ascending)
        XCTAssertEqual(model.rows.map(\.symbol), ["CCC", "AAA", "BBB", "DDD"])
    }

    func testSortFieldAndDirectionAreChosenIndependently() async {
        // AAA is the dearer stock but BBB moved more, so price and price change rank them differently.
        let (model, _) = await makeModel(quotes: [
            quote("AAA", price: 500, previousClose: 499), quote("BBB", price: 10, previousClose: 5),
        ])
        XCTAssertEqual(model.sortOption, .default)
        XCTAssertEqual(model.rows.prefix(2).map(\.symbol), ["AAA", "BBB"], "Default is price, high to low")

        model.sortOption.direction = .ascending
        XCTAssertEqual(model.sortOption.field, .price, "Changing the direction keeps the field")
        XCTAssertEqual(model.rows.prefix(2).map(\.symbol), ["BBB", "AAA"])

        model.sortOption.field = .priceChange
        XCTAssertEqual(model.sortOption.direction, .ascending, "Changing the field keeps the direction")
        XCTAssertEqual(model.rows.prefix(2).map(\.symbol), ["AAA", "BBB"])

        model.sortOption.direction = .descending
        XCTAssertEqual(model.sortOption.field, .priceChange)
        XCTAssertEqual(model.rows.prefix(2).map(\.symbol), ["BBB", "AAA"])
    }

    func testPersistenceTroubleShowsAWarningWithoutAFailureScreen() async {
        let (model, repository) = await makeModel(quotes: [quote("AAA", price: 10)])
        XCTAssertFalse(model.isPersistenceDegraded)
        repository.isPersistenceDegraded = true
        repository.feed.pushConnectionState(.connected)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertTrue(model.isPersistenceDegraded)
        XCTAssertNil(model.failurePresentation, "Disk trouble is a banner, never a blocking error")
        model.deactivate()
    }
}
