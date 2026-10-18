//
//  FeedUseCasePolicyTests.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import XCTest
@testable import LiveStockTracker

@MainActor
private final class SpyFeedSession: FeedSessionControlling, FeedStatusProviding {
    private(set) var calls: [String] = []
    var isStreamingRequested = false
    var currentConnectionState: FeedConnectionState = .idle
    func connectionEvents() -> AsyncStream<FeedConnectionState> { AsyncStream { $0.finish() } }

    func start() async { calls.append("start"); isStreamingRequested = true }
    func stop() async { calls.append("stop"); isStreamingRequested = false }
    func retry() async { calls.append("retry"); isStreamingRequested = true }
    func reconnect() async { calls.append("reconnect") }
    func setSceneActive(_ isActive: Bool) async { calls.append("scene:\(isActive)") }
}

@MainActor
final class FeedUseCasePolicyTests: XCTestCase {
    private let wifi = FeedNetworkPath(isSatisfied: true, interfaces: ["wifi:en0"])
    private let offline = FeedNetworkPath(isSatisfied: false, interfaces: [])

    private func make() -> (SpyFeedSession, MockStockRepository) {
        (SpyFeedSession(), MockStockRepository())
    }

    func testStartResetsOrderingThenStartsAndIsIdempotent() async {
        let (session, repository) = make()
        let start = DefaultStartFeedUseCase(session: session, status: session, repository: repository)
        await start.execute()
        await start.execute()
        XCTAssertEqual(session.calls, ["start"], "A second Start while running is ignored")
        XCTAssertEqual(repository.orderingResets, 1)
    }

    func testRetryResetsOrderingAndReplacesTheRun() async {
        let (session, repository) = make()
        await DefaultRetryFeedUseCase(session: session, repository: repository).execute()
        XCTAssertEqual(session.calls, ["retry"])
        XCTAssertEqual(repository.orderingResets, 1)
    }

    func testStopStopsWithoutTouchingQuoteOrdering() async {
        let (session, repository) = make()
        session.isStreamingRequested = true
        await DefaultStopFeedUseCase(session: session).execute()
        XCTAssertEqual(session.calls, ["stop"])
        XCTAssertEqual(repository.orderingResets, 0, "Stopping keeps the ordering window so a resumed run cannot show older prices")
    }

    func testSceneActivityIsMappedToTheSessionFlag() async {
        let (session, _) = make()
        let apply = DefaultApplySceneActivityUseCase(session: session)
        await apply.execute(.inactive)
        await apply.execute(.active)
        XCTAssertEqual(session.calls, ["scene:false", "scene:true"])
    }

    func testNetworkChangeReconnectsOnlyARunningFeedOntoAUsableNewRoute() async {
        struct Case {
            let path: FeedNetworkPath
            let initial: Bool
            let streaming: Bool
            let reconnects: Bool
        }
        let cases = [
            Case(path: wifi, initial: false, streaming: true, reconnects: true),
            Case(path: wifi, initial: true, streaming: true, reconnects: false),
            Case(path: offline, initial: false, streaming: true, reconnects: false),
            Case(path: wifi, initial: false, streaming: false, reconnects: false),
        ]
        for testCase in cases {
            let (session, _) = make()
            session.isStreamingRequested = testCase.streaming
            let handle = DefaultHandleNetworkPathChangeUseCase(session: session, status: session)
            await handle.execute(testCase.path, isInitial: testCase.initial)
            XCTAssertEqual(session.calls == ["reconnect"], testCase.reconnects,
                           "satisfied=\(testCase.path.isSatisfied) initial=\(testCase.initial) streaming=\(testCase.streaming)")
            XCTAssertFalse(session.calls.contains("start"), "Recovery must never start a feed")
        }
    }
}
