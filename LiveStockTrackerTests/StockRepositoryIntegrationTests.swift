//
//  StockRepositoryIntegrationTests.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import StockSocketKit
import SwiftData
import XCTest

@testable import LiveStockTracker

/// Test-only feed that drives terminal decode failure paths through the use case and repository.
private actor ControlledFailureEchoFeed {
    enum FailureMode: Sendable {
        /// Yields a tick that fails ``DomainQuoteMapping`` (empty symbol).
        case invalidDomainQuote
        /// Yields a transport-level decode failure (same end state as bad payload after framing).
        case transportDecodingFailed
        case serverNormalClose
    }

    private var streamContinuation: AsyncStream<WebSocketPublicEvent>.Continuation?
    private let failureMode: FailureMode

    init(failureMode: FailureMode) {
        self.failureMode = failureMode
    }

    func runBeginTransport() {
        let continuation = streamContinuation

        continuation?.yield(.connected)

        switch failureMode {
        case .invalidDomainQuote:
            for _ in 0..<EchoPriceFeed.maxConsecutiveInvalidBatches {
                continuation?.yield(
                    .decodedBatch([EchoStockPayload(symbol: "", price: 1, previousClose: 1, emittedAtEpoch: 0)])
                )
            }

        case .transportDecodingFailed:
            continuation?.yield(.transportFailure(.decodingFailed))
        case .serverNormalClose:
            continuation?.yield(.transportFailure(.closedByServer(code: 1000)))
        }
    }

    func runStopTransport() {
        let continuation = streamContinuation
        streamContinuation = nil
        continuation?.finish()
    }
}

extension ControlledFailureEchoFeed: StockEchoFeed {
    func eventsStream(
        bufferingPolicy: AsyncStream<WebSocketPublicEvent>.Continuation.BufferingPolicy
    ) async -> AsyncStream<WebSocketPublicEvent> {
        let (stream, continuation) = AsyncStream.makeStream(
            of: WebSocketPublicEvent.self,
            bufferingPolicy: bufferingPolicy
        )
        streamContinuation = continuation
        return stream
    }

    func beginTransport() async {
        runBeginTransport()
    }

    func stopTransport() async {
        runStopTransport()
    }

    func requestReconnect() async {}

    func applyOutboundSuspension(_ suspended: Bool) async {
        _ = suspended
    }
}

private struct BlackHoleLogging: Logging {
    nonisolated func log(_ level: LogLevel, _ message: @autoclosure () -> String) {}
}

@MainActor
private func waitUntilTrue(
    poll: Duration = .milliseconds(10),
    timeout: Duration = .seconds(8),
    condition: () async throws -> Bool
) async throws {
    let deadline = ContinuousClock.now + timeout

    while ContinuousClock.now < deadline {
        if try await condition() {
            return
        }
        try await Task.sleep(for: poll)
    }

    XCTFail("Condition not met before timeout")
}

@MainActor
final class StockRepositoryIntegrationTests: XCTestCase {
    func testPersistsDecodedTicksFromFakeEchoFeed() async throws {
        let catalog = [
            StockCatalogEntry(symbol: "AAA", companyName: "AAA Co", descriptionText: "Integration catalog row."),
        ]

        let schema = Schema([PersistedQuote.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])

        let epoch = Date().timeIntervalSince1970
        let payloads = [
            EchoStockPayload(symbol: "AAA", price: 12.34, previousClose: 11.5, emittedAtEpoch: epoch),
        ]

        let emitted = expectation(description: "FakeEchoFeed finished emitting payloads")

        let repository = FeedTestSystem(
            modelContainer: container,
            catalogEntries: catalog,
            logging: BlackHoleLogging(),
            echoFeedBuilder: { _ in
                FakeEchoFeed(payloads: payloads, onFinishedEmitting: {
                    emitted.fulfill()
                })
            },
        )

        await repository.startFeed.execute()
        await fulfillment(of: [emitted], timeout: 2)

        try await waitUntilTrue {
            try await repository.hasPersistedQuotes()
        }

        await repository.stopFeed.execute()

        let stillHasQuotes = try await repository.hasPersistedQuotes()
        XCTAssertTrue(stillHasQuotes)

        let snapshot = try await repository.persistedQuotesSnapshot(limit: 50, cursor: nil)
        XCTAssertEqual(snapshot.quotes.count, 1)
        XCTAssertEqual(snapshot.quotes.first?.symbol, "AAA")
        XCTAssertNil(snapshot.nextCursor)
    }

    func testPersistedQuotesSnapshotPagesBySymbolCursor() async throws {
        let catalog = [
            StockCatalogEntry(symbol: "AAA", companyName: "A", descriptionText: ""),
            StockCatalogEntry(symbol: "BBB", companyName: "B", descriptionText: ""),
        ]

        let schema = Schema([PersistedQuote.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])

        let epoch = Date().timeIntervalSince1970
        let payloads = [
            EchoStockPayload(symbol: "AAA", price: 1, previousClose: 1, emittedAtEpoch: epoch),
            EchoStockPayload(symbol: "BBB", price: 2, previousClose: 2, emittedAtEpoch: epoch),
        ]

        let emitted = expectation(description: "FakeEchoFeed finished emitting payloads")

        let repository = FeedTestSystem(
            modelContainer: container,
            catalogEntries: catalog,
            logging: BlackHoleLogging(),
            echoFeedBuilder: { _ in
                FakeEchoFeed(payloads: payloads, onFinishedEmitting: {
                    emitted.fulfill()
                })
            },
        )

        await repository.startFeed.execute()
        await fulfillment(of: [emitted], timeout: 2)

        try await waitUntilTrue {
            let page = try await repository.persistedQuotesSnapshot(limit: 10, cursor: nil)
            return page.quotes.count == 2
        }

        await repository.stopFeed.execute()

        let firstPage = try await repository.persistedQuotesSnapshot(limit: 1, cursor: nil)
        XCTAssertEqual(firstPage.quotes.map(\.symbol), ["AAA"])
        XCTAssertEqual(firstPage.nextCursor, "AAA")

        let secondPage = try await repository.persistedQuotesSnapshot(limit: 1, cursor: firstPage.nextCursor)
        XCTAssertEqual(secondPage.quotes.map(\.symbol), ["BBB"])
        XCTAssertNil(secondPage.nextCursor)
    }

    func testInvalidQuoteTickTerminatesWithDecodingFailed() async throws {
        let catalog = [
            StockCatalogEntry(symbol: "AAA", companyName: "AAA Co", descriptionText: "Row."),
        ]

        let schema = Schema([PersistedQuote.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])

        let repository = FeedTestSystem(
            modelContainer: container,
            catalogEntries: catalog,
            logging: BlackHoleLogging(),
            echoFeedBuilder: { _ in
                ControlledFailureEchoFeed(failureMode: .invalidDomainQuote)
            },
        )

        await repository.startFeed.execute()

        try await waitUntilTrue {
            repository.status.currentConnectionState == .failed(reason: .decodingFailed)
        }

        XCTAssertEqual(repository.status.currentConnectionState, .failed(reason: .decodingFailed))
        await repository.stopFeed.execute()
    }

    func testTransportDecodingFailureMapsToDecodingFailedState() async throws {
        let catalog = [
            StockCatalogEntry(symbol: "AAA", companyName: "AAA Co", descriptionText: "Row."),
        ]

        let schema = Schema([PersistedQuote.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])

        let repository = FeedTestSystem(
            modelContainer: container,
            catalogEntries: catalog,
            logging: BlackHoleLogging(),
            echoFeedBuilder: { _ in
                ControlledFailureEchoFeed(failureMode: .transportDecodingFailed)
            },
        )

        await repository.startFeed.execute()

        try await waitUntilTrue {
            repository.status.currentConnectionState == .failed(reason: .decodingFailed)
        }

        XCTAssertEqual(repository.status.currentConnectionState, .failed(reason: .decodingFailed))
        await repository.stopFeed.execute()
    }
}
