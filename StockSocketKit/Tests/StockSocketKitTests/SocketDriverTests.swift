//
//  SocketDriverTests.swift
//  StockSocketKit
//
//  Created by Muhammad Ali Maniar on 18/10/2026.
//

import XCTest
@testable import StockSocketKit

actor ScriptedSocket: EchoSocketConnection {
    let stream: AsyncThrowingStream<URLSessionWebSocketTask.Message, Error>
    let continuation: AsyncThrowingStream<URLSessionWebSocketTask.Message, Error>.Continuation
    let openFails: Bool
    let sendFails: Bool
    let pingBlocks: Bool
    let sendBlocks: Bool
    let blockedPing = WebSocketHandshakeAwaiter()
    let blockedSend = WebSocketHandshakeAwaiter()
    private(set) var pingCount = 0
    private(set) var firstCloseCode: URLSessionWebSocketTask.CloseCode?

    init(openFails: Bool = false, sendFails: Bool = false, pingBlocks: Bool = false, sendBlocks: Bool = false) {
        (stream, continuation) = AsyncThrowingStream.makeStream()
        self.openFails = openFails
        self.sendFails = sendFails
        self.pingBlocks = pingBlocks
        self.sendBlocks = sendBlocks
    }

    func open() throws {
        if openFails { throw URLError(.cannotConnectToHost) }
    }

    func receive() async throws -> URLSessionWebSocketTask.Message {
        var iterator = stream.makeAsyncIterator()
        guard let message = try await iterator.next() else { throw URLError(.networkConnectionLost) }
        return message
    }

    func send(_ message: URLSessionWebSocketTask.Message) async throws {
        if sendBlocks { try await blockedSend.waitHandshakeResult().get() }
        if sendFails { throw URLError(.networkConnectionLost) }
    }

    func ping() async throws {
        pingCount += 1
        if pingBlocks { try await blockedPing.waitHandshakeResult().get() }
    }
    func close(code: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        if firstCloseCode == nil { firstCloseCode = code }
        blockedPing.completeFailure(CancellationError())
        blockedSend.completeFailure(CancellationError())
        continuation.finish()
    }
    func serverClose(_ code: Int) {
        continuation.finish(throwing: WebSocketClose(code: code, reason: Data("Maintenance".utf8)))
    }
    func failRead() { continuation.finish(throwing: URLError(.networkConnectionLost)) }
    func deliver(_ text: String) { continuation.yield(.string(text)) }
}

actor SocketQueue {
    var sockets: [ScriptedSocket]
    init(_ sockets: [ScriptedSocket]) { self.sockets = sockets }
    func next() -> any EchoSocketConnection {
        if sockets.count > 1 { return sockets.removeFirst() }
        return sockets[0]
    }
}

final class SocketDriverTests: XCTestCase {
    private func session(_ sockets: [ScriptedSocket], metrics: EchoTransportMetrics? = nil) -> EchoWebSocketSession {
        let queue = SocketQueue(sockets)
        return EchoWebSocketSession(
            symbols: ["AAPL"],
            backoffPolicy: ExponentialBackoffPolicy(initialNanoseconds: 1_000_000, multiplier: 2,
                                                  maxNanoseconds: 8_000_000, jitterRatio: 0),
            transportMetrics: metrics,
            connectionBuilder: { await queue.next() }
        )
    }

    func testHandshakeTimeoutReturnsWithoutDelegateCallback() async {
        let handshake = WebSocketHandshakeAwaiter()
        let returned = expectation(description: "Timeout returned")
        let task = Task {
            let result = await handshake.waitHandshakeResult(timeoutNanoseconds: 1_000_000)
            if case .failure(let error as URLError) = result {
                XCTAssertEqual(error.code, .timedOut)
            } else {
                XCTFail("Expected handshake timeout")
            }
            returned.fulfill()
        }
        await fulfillment(of: [returned], timeout: 1)
        handshake.completeFailure(CancellationError())
        await task.value
    }

    func testTransientReceiveFailureReconnectsWithoutReachabilityChange() async {
        let first = ScriptedSocket()
        let second = ScriptedSocket()
        let session = session([first, second])
        let initial = expectation(description: "Initially connected")
        let recovered = expectation(description: "Reconnected after read failure")
        let tick = expectation(description: "Recovered connection delivers ticks")
        let stream = await session.wireEventsStream(bufferingPolicy: .unbounded)
        let reader = Task {
            var connectedCount = 0
            for await event in stream {
                if event == .connected {
                    connectedCount += 1
                    if connectedCount == 1 { initial.fulfill() } else { recovered.fulfill() }
                }
                if case .decodedBatch(let batch) = event, let payload = batch.first {
                    XCTAssertEqual(payload.symbol, "AAPL")
                    XCTAssertEqual(payload.price, 125)
                    tick.fulfill()
                }
            }
        }
        await session.start()
        await fulfillment(of: [initial], timeout: 1)
        await first.failRead()
        await fulfillment(of: [recovered], timeout: 1)
        await second.deliver("{\"symbol\":\"AAPL\",\"price\":125,\"previousClose\":100,\"emittedAtEpoch\":1}")
        await fulfillment(of: [tick], timeout: 1)
        await session.stop()
        await reader.value
    }

    func testTransientSendFailureReconnects() async {
        let session = session([ScriptedSocket(sendFails: true), ScriptedSocket()])
        let connected = expectation(description: "Both connections opened")
        connected.expectedFulfillmentCount = 2
        let stream = await session.wireEventsStream(bufferingPolicy: .unbounded)
        let reader = Task {
            for await event in stream where event == .connected { connected.fulfill() }
        }
        await session.start()
        await fulfillment(of: [connected], timeout: 1)
        await session.stop()
        await reader.value
    }

    func testFailedHandshakeRetriesAndReportsDriverMetrics() async {
        let retried = expectation(description: "Driver scheduled retry")
        let metrics = EchoTransportMetrics(onReconnectSleep: { attempt, delay in
            XCTAssertEqual(attempt, 1)
            XCTAssertEqual(delay, 1_000_000)
            retried.fulfill()
        })
        let session = session([ScriptedSocket(openFails: true), ScriptedSocket()], metrics: metrics)
        let connected = expectation(description: "Connected after failed handshake")
        let stream = await session.wireEventsStream(bufferingPolicy: .unbounded)
        let reader = Task {
            for await event in stream where event == .connected { connected.fulfill() }
        }
        await session.start()
        await fulfillment(of: [retried, connected], timeout: 1)
        await session.stop()
        await reader.value
    }

    func testCancelledStartDoesNotOpenANewConnection() async {
        let opened = expectation(description: "Cancelled start must not open")
        opened.isInverted = true
        let session = session([ScriptedSocket()], metrics: EchoTransportMetrics(onHandshakeCompleted: { _ in
            opened.fulfill()
        }))
        let start = Task {
            // Even a dependency that resumes a cancelled caller must not start transport.
            try? await Task.sleep(for: .seconds(60))
            await session.start()
        }
        start.cancel()
        await start.value
        await fulfillment(of: [opened], timeout: 0.1)
        await session.stop()
    }

    func testMissingPongReconnects() async {
        await assertHealthRecovery(first: ScriptedSocket(pingBlocks: true))
    }

    func testBlockedSendReconnects() async {
        await assertHealthRecovery(first: ScriptedSocket(sendBlocks: true))
    }

    private func assertHealthRecovery(first: ScriptedSocket) async {
        let queue = SocketQueue([first, ScriptedSocket()])
        let session = EchoWebSocketSession(
            symbols: ["AAPL"],
            backoffPolicy: ExponentialBackoffPolicy(initialNanoseconds: 1, multiplier: 2, maxNanoseconds: 10, jitter: .none),
            healthPolicy: EchoHealthPolicy(heartbeatIntervalNanoseconds: 1_000_000,
                                          pongTimeoutNanoseconds: 5_000_000, sendTimeoutNanoseconds: 5_000_000),
            connectionBuilder: { await queue.next() }
        )
        let recovered = expectation(description: "Two connections opened after health failure")
        recovered.expectedFulfillmentCount = 2
        let stream = await session.wireEventsStream(bufferingPolicy: .unbounded)
        let reader = Task {
            for await event in stream where event == .connected { recovered.fulfill() }
        }
        await session.start()
        await fulfillment(of: [recovered], timeout: 1)
        await session.stop()
        await reader.value
    }

    func testNormalServerCloseIsSurfacedAndDoesNotAutomaticallyRetry() async {
        let socket = ScriptedSocket()
        let session = session([socket])
        let terminal = expectation(description: "Server close ended feed")
        let metadata = expectation(description: "Close metadata preserved")
        let stream = await session.wireEventsStream(bufferingPolicy: .unbounded)
        let reader = Task {
            for await event in stream {
                if event == .connected { await socket.serverClose(1000) }
                if event == .serverClosed(code: 1000, reason: "Maintenance") { metadata.fulfill() }
                if event == .transportFailure(.closedByServer(code: 1000)) { terminal.fulfill() }
                if case .reconnectScheduled = event { XCTFail("Normal server closure must not reconnect automatically") }
            }
        }
        await session.start()
        await fulfillment(of: [terminal, metadata], timeout: 1)
        await session.stop()
        await reader.value
    }

    func testNetworkChangeReconnectsThroughBackoffAndStopUsesNormalClose() async {
        let first = ScriptedSocket()
        let second = ScriptedSocket()
        let retry = expectation(description: "Network change uses retry policy")
        let session = session([first, second], metrics: EchoTransportMetrics(onReconnectSleep: { attempt, delay in
            XCTAssertEqual(attempt, 1)
            XCTAssertEqual(delay, 1_000_000)
            retry.fulfill()
        }))
        let connected = expectation(description: "Initial and replacement connections")
        connected.expectedFulfillmentCount = 2
        let stream = await session.wireEventsStream(bufferingPolicy: .unbounded)
        let reader = Task {
            var count = 0
            for await event in stream where event == .connected {
                count += 1
                connected.fulfill()
                if count == 1 { await session.invalidateCurrentConnection() }
            }
        }
        await session.start()
        await fulfillment(of: [connected, retry], timeout: 1)
        await session.stop()
        await reader.value
        let firstCode = await first.firstCloseCode
        let secondCode = await second.firstCloseCode
        XCTAssertEqual(firstCode, .goingAway)
        XCTAssertEqual(secondCode, .normalClosure)
    }

    func testStopDuringBackoffCancelsRetryAndFinishesStream() async {
        let sleeping = expectation(description: "Retry delay started")
        let session = EchoWebSocketSession(
            symbols: ["AAPL"],
            backoffPolicy: ExponentialBackoffPolicy(initialNanoseconds: 123, multiplier: 2,
                                                  maxNanoseconds: 123, jitterRatio: 0),
            connectionBuilder: { ScriptedSocket(openFails: true) },
            sleep: { delay in
                XCTAssertEqual(delay, 123)
                sleeping.fulfill()
                try await Task.sleep(for: .seconds(60))
            }
        )
        let stream = await session.wireEventsStream(bufferingPolicy: .unbounded)
        let reader = Task { () -> [WebSocketPublicEvent] in
            var events: [WebSocketPublicEvent] = []
            for await event in stream { events.append(event) }
            return events
        }
        await session.start()
        await fulfillment(of: [sleeping], timeout: 1)
        await session.stop()
        let events = await reader.value
        XCTAssertEqual(events, [.reconnectScheduled(attempt: 1), .disconnected(userInitiated: true)])
    }

    func testRunOfMalformedPayloadsIsTerminal() async {
        let socket = ScriptedSocket()
        let session = session([socket])
        let failed = expectation(description: "Malformed data is terminal")
        let stream = await session.wireEventsStream(bufferingPolicy: .unbounded)
        let reader = Task {
            for await event in stream {
                if event == .connected {
                    for _ in 0..<EchoHealthPolicy().maxConsecutiveDecodeFailures { await socket.deliver("not JSON") }
                }
                if case .transportFailure(let failure) = event {
                    XCTAssertEqual(failure, .decodingFailed)
                    failed.fulfill()
                }
                if case .reconnectScheduled = event { XCTFail("Malformed data must not loop forever") }
            }
        }
        await session.start()
        await fulfillment(of: [failed], timeout: 1)
        let closeCode = await socket.firstCloseCode
        XCTAssertEqual(closeCode, .unsupportedData)
        await session.stop()
        await reader.value
    }
}
