//
//  PriceFeedBoundaryTests.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import XCTest
@testable import LiveStockTracker

@MainActor
final class FeedSessionCoordinatorTests: XCTestCase {
    func testApplicationFeedDeliversQuotesAndTerminalFailureStopsItsSession() async throws {
        let repository = MockStockRepository()
        let source = ApplicationFeedStub()
        let coordinator = FeedSessionCoordinator(repository: repository, feedBuilder: { _ in source })
        let quote = StockQuote(symbol: "AAPL", price: 150, previousClose: 140, updatedAt: .now)
        await coordinator.start()
        source.emit(.quotes([quote]))
        try await eventually { repository.currentMergedQuotes() == [quote] }
        source.emit(.connection(.failed(reason: .closedByServer)))
        try await eventually { source.stopCount == 1 }
        XCTAssertFalse(coordinator.isStreamingRequested)
        XCTAssertEqual(coordinator.currentConnectionState, .failed(reason: .closedByServer))
        await coordinator.stop()
    }

    func testReleasingCoordinatorStopsItsActiveSession() async throws {
        let source = ApplicationFeedStub()
        var coordinator: FeedSessionCoordinator? = FeedSessionCoordinator(repository: MockStockRepository(), feedBuilder: { _ in source })
        weak let releasedCoordinator = coordinator
        await coordinator?.start()
        try await eventually { coordinator?.currentConnectionState == .connected }
        coordinator = nil
        try await eventually { source.stopCount == 1 }
        XCTAssertNil(releasedCoordinator)
    }

    func testNewStartWaitsForTerminalCleanupBeforeConstructingItsSession() async throws {
        let repository = MockStockRepository()
        let first = ApplicationFeedStub()
        let second = ApplicationFeedStub()
        first.suspendStop = true
        var builds = 0
        let coordinator = FeedSessionCoordinator(repository: repository, feedBuilder: { _ in
            builds += 1
            return builds == 1 ? first : second
        })
        await coordinator.start()
        first.emit(.connection(.failed(reason: .transportUnavailable)))
        try await eventually { first.stopCount == 1 }
        let restart = Task { await coordinator.start() }
        try await eventually { coordinator.currentConnectionState == .connecting }
        XCTAssertEqual(builds, 1, "The old session must finish cleanup before a new one is constructed")
        first.releaseStop()
        await restart.value
        try await eventually { coordinator.currentConnectionState == .connected }
        XCTAssertEqual(builds, 2)
        await coordinator.stop()
    }

}

@MainActor
private final class ApplicationFeedStub: PriceFeed {
    private let stream: AsyncStream<PriceFeedEvent>
    private let continuation: AsyncStream<PriceFeedEvent>.Continuation
    private(set) var stopCount = 0
    var suspendStop = false
    private var stopGate: CheckedContinuation<Void, Never>?

    init() { (stream, continuation) = AsyncStream.makeStream() }
    func events() async -> AsyncStream<PriceFeedEvent> { stream }
    func start() async { continuation.yield(.connection(.connected)) }
    func stop() async {
        stopCount += 1
        if suspendStop { await withCheckedContinuation { stopGate = $0 } }
        continuation.finish()
    }
    func releaseStop() { suspendStop = false; stopGate?.resume(); stopGate = nil }
    func reconnect() async {}
    func setSuspended(_ suspended: Bool) async {}
    func emit(_ event: PriceFeedEvent) { continuation.yield(event) }
}
