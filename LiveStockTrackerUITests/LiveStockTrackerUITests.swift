//
//  LiveStockTrackerUITests.swift
//  LiveStockTrackerUITests
//
//  Created by Muhammad Ali Maniar on 17/10/2026.
//

import XCTest

// TEMPORARY (feature/feed-pipeline): one smoke test so the UI test target has something to run.
// feature/ui replaces it with the real launch, sort, detail and Arabic tests.
final class LiveStockTrackerUITests: XCTestCase {
    @MainActor
    func testLaunchShowsTheFeedControls() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.navigationBars["Stocks"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Start"].exists)
        XCTAssertTrue(app.buttons["Stop"].exists)
    }
}
