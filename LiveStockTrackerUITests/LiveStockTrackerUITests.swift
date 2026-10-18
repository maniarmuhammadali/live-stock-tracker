//
//  LiveStockTrackerUITests.swift
//  LiveStockTrackerUITests
//
//  Created by Muhammad Ali Maniar on 17/10/2026.
//

import XCTest

final class LiveStockTrackerUITests: XCTestCase {

    @MainActor
    func testLaunchShowsTheBundledCatalog() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.navigationBars["Stocks"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Apple Inc."].waitForExistence(timeout: 5))
    }
}
