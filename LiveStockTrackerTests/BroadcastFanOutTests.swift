//
//  BroadcastFanOutTests.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import XCTest
@testable import LiveStockTracker

final class BroadcastFanOutTests: XCTestCase {
    func testSlowSubscriberDropsAreCounted() {
        let fanOut = BroadcastFanOut<Int>()
        let stream = fanOut.makeStream(bufferingPolicy: .bufferingOldest(2))
        for value in 0..<5 { fanOut.yield(value) }
        XCTAssertEqual(fanOut.droppedCount, 3)
        withExtendedLifetime(stream) {}
    }

    func testTerminatedSubscriberIsRemoved() async {
        let fanOut = BroadcastFanOut<Int>()
        var stream: AsyncStream<Int>? = fanOut.makeStream()
        XCTAssertEqual(fanOut.subscriberCount, 1)
        stream = nil
        _ = stream
        for _ in 0..<50 where fanOut.subscriberCount > 0 { await Task.yield() }
        XCTAssertEqual(fanOut.subscriberCount, 0)
    }

    func testFinishAllEndsEverySubscriber() async {
        let fanOut = BroadcastFanOut<Int>()
        let first = fanOut.makeStream()
        let second = fanOut.makeStream()
        fanOut.yield(1)
        fanOut.finishAll()
        var firstValues: [Int] = []
        for await value in first { firstValues.append(value) }
        var secondValues: [Int] = []
        for await value in second { secondValues.append(value) }
        XCTAssertEqual(firstValues, [1])
        XCTAssertEqual(secondValues, [1])
        XCTAssertEqual(fanOut.subscriberCount, 0)
    }
}
