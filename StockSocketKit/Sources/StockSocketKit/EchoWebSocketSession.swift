//
//  EchoWebSocketSession.swift
//  StockSocketKit
//
//  Created by Muhammad Ali Maniar on 18/10/2026.
//

import Foundation
import os

public actor EchoWebSocketSession {
    typealias ConnectionBuilder = @Sendable () async -> any EchoSocketConnection
    typealias Sleeper = @Sendable (UInt64) async throws -> Void

    private enum Phase {
        case building
        case opening(any EchoSocketConnection)
        case open(any EchoSocketConnection)
        case backingOff

        var socket: (any EchoSocketConnection)? {
            switch self {
            case let .opening(socket), let .open(socket): return socket
            case .building, .backingOff: return nil
            }
        }
    }

    private struct Run {
        let id: UUID
        var task: Task<Void, Never>?
        var phase = Phase.building
        var receivedTickSinceConnect = false
        var reportedServerClose = false
        var consecutiveDecodeFailures = 0
        var attemptStartedAt: ContinuousClock.Instant?
        var connectInterval: OSSignpostIntervalState?
    }

    private let logger: EchoLogger?
    private let backoffPolicy: ExponentialBackoffPolicy
    private let outboundIntervalNanoseconds: UInt64
    private let handshakeTimeoutNanoseconds: UInt64
    private let transportMetrics: EchoTransportMetrics?
    private let jsonDecoder: JSONDecoder
    private let jsonEncoder: JSONEncoder
    private let connectionBuilder: ConnectionBuilder
    private let sleep: Sleeper
    private let healthPolicy: EchoHealthPolicy
    private let signposter = OSSignposter(subsystem: "com.stocktracker.socket", category: "transport")
    private var generator: SyntheticPriceGenerator
    private var continuation: AsyncStream<WebSocketPublicEvent>.Continuation?
    private var streamID = UUID()
    private var run: Run?
    private var outboundSuspended = false
    private var suspensionObservedSinceWatchdogCheck = false
    private var counters = EchoTransportDiagnostics()

    public init(
        url: URL,
        symbols: [String],
        outboundIntervalNanoseconds: UInt64,
        backoffPolicy: ExponentialBackoffPolicy,
        logger: EchoLogger?,
        tlsHooks: EchoTLSHooks = EchoTLSHooks(),
        transportMetrics: EchoTransportMetrics? = nil,
        handshakeTimeoutNanoseconds: UInt64 = EchoTransportDefaults.handshakeTimeoutNanoseconds,
        jsonDecoder: JSONDecoder = JSONDecoder(),
        jsonEncoder: JSONEncoder = JSONEncoder(),
        healthPolicy: EchoHealthPolicy = EchoHealthPolicy()
    ) {
        self.healthPolicy = healthPolicy
        self.generator = SyntheticPriceGenerator(symbols: symbols)
        self.logger = logger
        self.backoffPolicy = backoffPolicy
        self.outboundIntervalNanoseconds = outboundIntervalNanoseconds
        self.handshakeTimeoutNanoseconds = handshakeTimeoutNanoseconds
        self.transportMetrics = transportMetrics
        self.jsonDecoder = jsonDecoder
        self.jsonEncoder = jsonEncoder
        self.connectionBuilder = {
            URLSessionEchoSocketConnection(url: url, tlsHooks: tlsHooks, timeout: handshakeTimeoutNanoseconds)
        }
        self.sleep = { try await Task.sleep(nanoseconds: $0) }
    }

    init(
        symbols: [String],
        backoffPolicy: ExponentialBackoffPolicy,
        outboundIntervalNanoseconds: UInt64 = EchoTransportDefaults.outboundIntervalNanoseconds,
        healthPolicy: EchoHealthPolicy = EchoHealthPolicy(),
        transportMetrics: EchoTransportMetrics? = nil,
        generator: SyntheticPriceGenerator? = nil,
        connectionBuilder: @escaping ConnectionBuilder,
        sleep: @escaping Sleeper = { try await Task.sleep(nanoseconds: $0) }
    ) {
        self.healthPolicy = healthPolicy
        self.generator = generator ?? SyntheticPriceGenerator(symbols: symbols)
        self.logger = nil
        self.backoffPolicy = backoffPolicy
        self.outboundIntervalNanoseconds = outboundIntervalNanoseconds
        self.handshakeTimeoutNanoseconds = EchoTransportDefaults.handshakeTimeoutNanoseconds
        self.transportMetrics = transportMetrics
        self.jsonDecoder = JSONDecoder()
        self.jsonEncoder = JSONEncoder()
        self.connectionBuilder = connectionBuilder
        self.sleep = sleep
    }

    public var handshakeTimeoutNanosecondsConfigured: UInt64 { handshakeTimeoutNanoseconds }

    public func diagnostics() -> EchoTransportDiagnostics { counters }

    public func wireEventsStream(
        bufferingPolicy: AsyncStream<WebSocketPublicEvent>.Continuation.BufferingPolicy = WebSocketPublicEventStreamDefaults.bufferingPolicy
    ) -> AsyncStream<WebSocketPublicEvent> {
        let id = UUID()
        streamID = id
        continuation?.finish()
        return AsyncStream(bufferingPolicy: bufferingPolicy) { continuation in
            self.continuation = continuation
            continuation.onTermination = { @Sendable _ in
                Task { await self.handleStreamTermination(id: id) }
            }
        }
    }

    public func start() {
        guard !Task.isCancelled, run == nil else { return }
        let id = UUID()
        run = Run(id: id)
        run?.task = Task { await self.runDriver(id: id) }
    }

    public func stop() async {
        let finished = run
        run = nil
        let oldContinuation = continuation
        continuation = nil
        oldContinuation?.yield(.disconnected(userInitiated: true))
        oldContinuation?.finish()
        if let interval = finished?.connectInterval { signposter.endInterval("ConnectToFirstTick", interval) }
        await finished?.phase.socket?.close(code: .normalClosure, reason: nil)
        finished?.task?.cancel()
        await finished?.task?.value
        logger?.info("Echo session stopped \(describe(counters))")
    }

    func invalidateCurrentConnection() async {
        guard let run, run.task != nil else { return }
        await run.phase.socket?.close(code: .goingAway, reason: nil)
    }

    public func setOutboundSuspended(_ suspended: Bool) {
        outboundSuspended = suspended
        if suspended { suspensionObservedSinceWatchdogCheck = true }
    }

    private func handleStreamTermination(id: UUID) async {
        guard streamID == id else { return }
        await stop()
    }

    private func isCurrent(_ id: UUID) -> Bool {
        run?.id == id && !Task.isCancelled
    }

    private func emit(_ event: WebSocketPublicEvent) {
        guard let continuation else { return }
        if case .dropped = continuation.yield(event) {
            counters.eventsDropped += 1
            transportMetrics?.onEventDropped?(event)
        }
    }

    private func describe(_ counters: EchoTransportDiagnostics) -> String {
        "frames=\(counters.framesDecoded) droppedFrames=\(counters.framesDropped) droppedEvents=\(counters.eventsDropped) "
            + "reconnects=\(counters.reconnects) stale=\(counters.staleDataReconnects)"
    }

    // MARK: Driver

    private func runDriver(id: UUID) async {
        defer { finishDriver(id: id) }
        var reconnectAttempt = 0
        while isCurrent(id) {
            beginAttempt(id)
            let socket = await connectionBuilder()
            guard isCurrent(id) else {
                await socket.close()
                return
            }
            run?.phase = .opening(socket)
            run?.reportedServerClose = false
            do {
                try await socket.open()
                guard isCurrent(id) else {
                    await socket.close()
                    return
                }
                transportMetrics?.onHandshakeCompleted?(true)
                run?.receivedTickSinceConnect = false
                run?.consecutiveDecodeFailures = 0
                run?.phase = .open(socket)
                emit(.connected)
                let failure = await runIO(socket: socket, id: id)
                await socket.close()
                guard isCurrent(id) else { return }
                if run?.receivedTickSinceConnect == true { reconnectAttempt = 0 }
                if finishIfTerminal(failure) { return }
                emit(.disconnected(userInitiated: false))
            } catch {
                await socket.close()
                guard isCurrent(id) else { return }
                counters.handshakeFailures += 1
                transportMetrics?.onHandshakeCompleted?(false)
                if handleHandshakeFailure(error) { return }
            }
            run?.phase = .backingOff
            endConnectInterval()
            let delay = backoffPolicy.delayNanoseconds(forAttempt: reconnectAttempt)
            reconnectAttempt = min(reconnectAttempt + 1, 60)
            counters.reconnects += 1
            emit(.reconnectScheduled(attempt: reconnectAttempt))
            transportMetrics?.onReconnectSleep?(reconnectAttempt, delay)
            do {
                try await sleep(delay)
            } catch {
                return
            }
        }
    }

    private func finishDriver(id: UUID) {
        guard run?.id == id else { return }
        endConnectInterval()
        run = nil
    }

    private func beginAttempt(_ id: UUID) {
        guard run?.id == id else { return }
        run?.phase = .building
        run?.attemptStartedAt = .now
        run?.connectInterval = signposter.beginInterval("ConnectToFirstTick")
    }

    private func endConnectInterval() {
        guard let interval = run?.connectInterval else { return }
        signposter.endInterval("ConnectToFirstTick", interval)
        run?.connectInterval = nil
    }

    private func recordFirstTickIfNeeded() {
        guard run?.receivedTickSinceConnect == false else { return }
        run?.receivedTickSinceConnect = true
        endConnectInterval()
        guard let started = run?.attemptStartedAt else { return }
        let elapsed = started.duration(to: .now)
        let milliseconds = Int(elapsed.components.seconds * 1000 + elapsed.components.attoseconds / 1_000_000_000_000_000)
        counters.lastTimeToFirstTickMilliseconds = milliseconds
        transportMetrics?.onTimeToFirstTick?(milliseconds)
    }

    private func handleHandshakeFailure(_ error: Error) -> Bool {
        if let close = error as? WebSocketClose {
            reportServerClose(close)
            if !close.shouldRetry {
                emitTerminal(.closedByServer(code: close.code))
                return true
            }
        }
        logger?.debug("WebSocket handshake failed \(error.localizedDescription)")
        return false
    }

    // MARK: I/O loops

    private func runIO(socket: any EchoSocketConnection, id: UUID) async -> WebSocketTransportFailure? {
        await withTaskGroup(of: WebSocketTransportFailure?.self) { group in
            group.addTask { await self.receiveLoop(socket: socket, id: id) }
            group.addTask { await self.outboundLoop(socket: socket, id: id) }
            group.addTask { await self.heartbeatLoop(socket: socket, id: id) }
            group.addTask { await self.staleDataWatchdog(id: id) }
            let failure = await group.next() ?? nil
            let code: URLSessionWebSocketTask.CloseCode
            switch failure {
            case .decodingFailed: code = .unsupportedData
            case let .closedByServer(serverCode): code = WebSocketClose(code: serverCode, reason: nil).responseCode
            default: code = .goingAway
            }
            await socket.close(code: code, reason: nil)
            group.cancelAll()
            return failure
        }
    }

    private func receiveLoop(socket: any EchoSocketConnection, id: UUID) async -> WebSocketTransportFailure? {
        while isCurrent(id) {
            do {
                let message = try await socket.receive()
                guard isCurrent(id) else { return nil }
                if let failure = ingest(message) { return failure }
            } catch {
                guard isCurrent(id) else { return nil }
                return failure(from: error, timeout: .closedUnexpectedly)
            }
        }
        return nil
    }

    /// Decodes one frame. A bad frame is dropped and counted; only a run of them ends the feed.
    private func ingest(_ message: URLSessionWebSocketTask.Message) -> WebSocketTransportFailure? {
        let data: Data?
        switch message {
        case let .string(text): data = Data(text.utf8)
        case let .data(bytes): data = bytes
        @unknown default: data = nil
        }
        guard let data, let batch = EchoWireDecoder.decode(data, using: jsonDecoder) else {
            counters.framesDropped += 1
            transportMetrics?.onFrameDropped?()
            run?.consecutiveDecodeFailures += 1
            let streak = run?.consecutiveDecodeFailures ?? 0
            logger?.debug("Dropped undecodable frame (\(streak) in a row)")
            return streak >= healthPolicy.maxConsecutiveDecodeFailures ? .decodingFailed : nil
        }
        run?.consecutiveDecodeFailures = 0
        counters.framesDecoded += 1
        recordFirstTickIfNeeded()
        if !batch.isEmpty { emit(.decodedBatch(batch)) }
        return nil
    }

    private func outboundLoop(socket: any EchoSocketConnection, id: UUID) async -> WebSocketTransportFailure? {
        while isCurrent(id) {
            do {
                if outboundSuspended {
                    try await sleep(250_000_000)
                    continue
                }
                let snapshot = generator.makeSnapshot(emittedAtEpoch: Date().timeIntervalSince1970)
                let data = try jsonEncoder.encode(snapshot)
                guard let text = String(data: data, encoding: .utf8) else { return .decodingFailed }
                try await withSocketDeadline(socket: socket, nanoseconds: healthPolicy.sendTimeoutNanoseconds, sleep: sleep) {
                    try await socket.send(.string(text))
                }
                try await sleep(outboundIntervalNanoseconds)
            } catch {
                guard isCurrent(id) else { return nil }
                return failure(from: error, timeout: .sendTimedOut)
            }
        }
        return nil
    }

    private func heartbeatLoop(socket: any EchoSocketConnection, id: UUID) async -> WebSocketTransportFailure? {
        while isCurrent(id) {
            do {
                try await sleep(healthPolicy.heartbeatIntervalNanoseconds)
                guard isCurrent(id) else { return nil }
                if outboundSuspended { continue }
                try await withSocketDeadline(socket: socket, nanoseconds: healthPolicy.pongTimeoutNanoseconds, sleep: sleep) {
                    try await socket.ping()
                }
            } catch {
                guard isCurrent(id) else { return nil }
                logger?.debug("WebSocket heartbeat failed \(error.localizedDescription)")
                return failure(from: error, timeout: .heartbeatTimedOut)
            }
        }
        return nil
    }

    /// Ping/pong proves the socket is alive, not that data flows. If a whole window passes with no decoded frame
    /// the link is replaced. Windows that overlap a background suspension are forgiven once.
    private func staleDataWatchdog(id: UUID) async -> WebSocketTransportFailure? {
        var lastSeen = counters.framesDecoded
        while isCurrent(id) {
            do {
                try await sleep(healthPolicy.staleDataTimeoutNanoseconds)
            } catch {
                guard isCurrent(id) else { return nil }
                return .closedUnexpectedly
            }
            guard isCurrent(id) else { return nil }
            if outboundSuspended || suspensionObservedSinceWatchdogCheck {
                suspensionObservedSinceWatchdogCheck = false
                lastSeen = counters.framesDecoded
                continue
            }
            if counters.framesDecoded == lastSeen {
                counters.staleDataReconnects += 1
                transportMetrics?.onStaleData?()
                logger?.debug("No data for the stale-data window; replacing the connection")
                return .staleData
            }
            lastSeen = counters.framesDecoded
        }
        return nil
    }

    // MARK: Failure classification

    private func failure(from error: Error, timeout: WebSocketTransportFailure) -> WebSocketTransportFailure {
        if let close = error as? WebSocketClose {
            reportServerClose(close)
            return .closedByServer(code: close.code)
        }
        if let error = error as? URLError, error.code == .timedOut { return timeout }
        return .closedUnexpectedly
    }

    private func reportServerClose(_ close: WebSocketClose) {
        guard run?.reportedServerClose == false else { return }
        run?.reportedServerClose = true
        emit(.serverClosed(code: close.code, reason: close.reason.flatMap { String(data: $0, encoding: .utf8) }))
    }

    private func isTerminal(_ failure: WebSocketTransportFailure) -> Bool {
        switch failure {
        case .decodingFailed: return true
        case let .closedByServer(code): return !WebSocketClose(code: code, reason: nil).shouldRetry
        default: return false
        }
    }

    private func finishIfTerminal(_ failure: WebSocketTransportFailure?) -> Bool {
        guard let failure, isTerminal(failure) else { return false }
        emitTerminal(failure)
        return true
    }

    private func emitTerminal(_ failure: WebSocketTransportFailure) {
        transportMetrics?.onTerminalTransportFailure?(failure)
        emit(.transportFailure(failure))
    }
}
