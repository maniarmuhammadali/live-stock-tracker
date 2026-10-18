//
//  TestSupport.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import XCTest
@testable import LiveStockTracker

/// Intentionally noncooperative: callers must also check cancellation before publishing.
@MainActor
final class ManualQuoteDelay {
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private(set) var sleeps = 0
    func sleep(_ duration: Duration) async throws {
        await withCheckedContinuation { continuation in
            sleeps += 1
            waiters.append(continuation)
        }
    }
    func advance() {
        let pending = waiters
        waiters.removeAll()
        for continuation in pending { continuation.resume() }
    }
}

@MainActor
func eventually(_ predicate: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async throws {
    let deadline = ContinuousClock.now + .seconds(2)
    while !predicate() {
        guard ContinuousClock.now < deadline else {
            XCTFail("Condition did not become true", file: file, line: line)
            throw CancellationError()
        }
        try await Task.sleep(for: .milliseconds(1))
    }
}

struct LifecycleLogging: Logging {
    nonisolated func log(_ level: LogLevel, _ message: @autoclosure () -> String) {}
}
