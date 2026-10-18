//
//  FeedURLConfigurationTests.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 18/10/2026.
//

import XCTest

@testable import LiveStockTracker

final class FeedURLConfigurationTests: XCTestCase {
    func testBundleProvidesConfiguredWebSocketURL() {
        let url = FeedTransportConfiguration.makeDefaultSocketURL()
        XCTAssertEqual(url?.scheme, "wss")
        XCTAssertEqual(url?.host, "ws.postman-echo.com")
        XCTAssertTrue(url?.path.contains("raw") == true)
    }
}
