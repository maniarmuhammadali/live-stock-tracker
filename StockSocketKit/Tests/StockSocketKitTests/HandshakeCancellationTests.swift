//
//  HandshakeCancellationTests.swift
//  StockSocketKit
//
//  Created by Muhammad Ali Maniar on 18/10/2026.
//

import XCTest
@testable import StockSocketKit

final class HandshakeCancellationTests: XCTestCase {
    func testCancelledHandshakeWaitReturnsWithoutDelegateCallback() async {
        let handshake = WebSocketHandshakeAwaiter()
        let returned = expectation(description: "Cancelled waiter returned")
        let task = Task {
            let result = await handshake.waitHandshakeResult()
            if case .failure(let error) = result {
                XCTAssertTrue(error is CancellationError)
            } else {
                XCTFail("Cancelled handshake must fail")
            }
            returned.fulfill()
        }
        task.cancel()
        await fulfillment(of: [returned], timeout: 0.2)
        // Release the old implementation after the assertion to avoid leaking a task on RED.
        handshake.completeFailure(CancellationError())
        await task.value
    }
}
