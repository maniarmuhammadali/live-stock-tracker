//
//  LiveStockTrackerUITests.swift
//  LiveStockTrackerUITests
//
//  Created by Muhammad Ali Maniar on 17/10/2026.
//

import XCTest

final class LiveStockTrackerUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(language: String = "en", locale: String = "en_US", rtlFixtures: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(\(language))", "-AppleLocale", locale]
        if rtlFixtures { app.launchArguments += ["--ui-testing-rtl-fixtures"] }
        app.launch()
        return app
    }

    @MainActor
    func testStartStopSortAndNavigateToDetail() {
        let app = launch()
        XCTAssertTrue(app.navigationBars["Stocks App"].waitForExistence(timeout: 8))
        let toggle = app.buttons["toolbar.feed_toggle"]
        _ = firstRowIdentifier(app)
        XCTAssertEqual(toggle.label, "Stop streaming stock prices", "The feed starts on launch")
        let firstRow = app.buttons["stock.row.AAPL"]
        // Default price-descending sorting puts AAPL at the bottom of 25 rows.
        app.buttons["toolbar.sort"].tap()
        app.buttons["Low to High"].tap()
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5))
        firstRow.tap()
        XCTAssertTrue(app.navigationBars["AAPL"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["detail.price"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["detail.price"].label, "$100.00")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        toggle.tap()
        XCTAssertEqual(toggle.label, "Start streaming stock prices")
        XCTAssertTrue(app.buttons["stock.row.AAPL"].exists, "Cached quotes remain visible after Stop")
    }

    @MainActor
    private func firstRowIdentifier(_ app: XCUIApplication) -> String {
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'stock.row.'"))
        XCTAssertTrue(rows.element(boundBy: 0).waitForExistence(timeout: 8))
        return rows.element(boundBy: 0).identifier
    }

    @MainActor
    func testListIsLiveOnLaunch() {
        let app = launch()
        _ = firstRowIdentifier(app)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "message.view").firstMatch.exists)
        XCTAssertEqual(app.buttons["toolbar.feed_toggle"].label, "Stop streaming stock prices")
    }

    @MainActor
    func testArabicInterfaceAndLocalizedPriceInRTL() {
        let app = launch(language: "ar", locale: "ar_EG", rtlFixtures: true)
        XCTAssertTrue(app.navigationBars["تطبيق الأسهم"].waitForExistence(timeout: 8))
        app.buttons["toolbar.sort"].tap()
        app.buttons["من الأقل إلى الأعلى"].tap()
        let row = app.buttons["stock.row.AAPL"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(app.buttons["toolbar.feed_toggle"].frame.midX, 0)
        XCTAssertLessThan(app.buttons["toolbar.feed_toggle"].frame.midX,
                          app.buttons["toolbar.theme_toggle"].frame.midX, "RTL toolbar order must mirror English")
        attachScreenshot(app, name: "Arabic list RTL")
        row.tap()
        let price = app.staticTexts["detail.price"]
        XCTAssertTrue(price.waitForExistence(timeout: 5))
        XCTAssertTrue(price.label.contains("١٠٠٫٠٠"), price.label)
        XCTAssertEqual(price.frame.maxX, app.staticTexts["detail.last_price_label"].frame.maxX, accuracy: 2,
                       "Price section must align with Arabic semantic leading edge")
        attachScreenshot(app, name: "Arabic detail RTL")
        XCTAssertTrue(app.staticTexts["detail.movement"].label.contains("-"))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["stock.row.ADBE"].tap()
        let positive = app.staticTexts["detail.movement"]
        XCTAssertTrue(positive.waitForExistence(timeout: 5))
        XCTAssertTrue(positive.label.contains("+"), positive.label)
        attachScreenshot(app, name: "Arabic positive detail RTL")
    }

    @MainActor
    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
