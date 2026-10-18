//
//  EchoWebSocketSession.swift
//  StockSocketKit
//
//  Created by Muhammad Ali Maniar on 18/10/2026.
//

import Foundation

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
    private var generator: SyntheticPriceGenerator
    private var continuation: AsyncStream<WebSocketPublicEvent>.Continuation?
    private var streamID = UUID()
    private var run: Run?
    private var outboundSuspended = false

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
        jsonEncoder: JSONEncoder = JSONEncoder()
    ) {
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
        transportMetrics: EchoTransportMetrics? = nil,
        generator: SyntheticPriceGenerator? = nil,
        connectionBuilder: @escaping ConnectionBuilder,
        sleep: @escaping Sleeper = { try await Task.sleep(nanoseconds: $0) }
    ) {
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
        await finished?.phase.socket?.close(code: .normalClosure, reason: nil)
        finished?.task?.cancel()
        await finished?.task?.value
        logger?.info("Echo session stopped")
    }

    func invalidateCurrentConnection() async {
        guard let run, run.task != nil else { return }
        await run.phase.socket?.close(code: .goingAway, reason: nil)
    }

    public func setOutboundSuspended(_ suspended: Bool) {
        outboundSuspended = suspended
    }

    private func handleStreamTermination(id: UUID) async {
        guard streamID == id else { return }
        await stop()
    }

    private func isCurrent(_ id: UUID) -> Bool {
        run?.id == id && !Task.isCancelled
    }

    private func emit(_ event: WebSocketPublicEvent) {
        continuation?.yield(event)
    }

    // MARK: Driver

    private func runDriver(id: UUID) async {
        defer { finishDriver(id: id) }
        var reconnectAttempt = 0
        while isCurrent(id) {
            run?.phase = .building
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
                transportMetrics?.onHandshakeCompleted?(false)
                if handleHandshakeFailure(error) { return }
            }
            run?.phase = .backingOff
            let delay = backoffPolicy.delayNanoseconds(forAttempt: reconnectAttempt)
            reconnectAttempt = min(reconnectAttempt + 1, 60)
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
        run = nil
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
                return failure(from: error)
            }
        }
        return nil
    }

    private func ingest(_ message: URLSessionWebSocketTask.Message) -> WebSocketTransportFailure? {
        let data: Data?
        switch message {
        case let .string(text): data = Data(text.utf8)
        case let .data(bytes): data = bytes
        @unknown default: data = nil
        }
        guard let data, let batch = EchoWireDecoder.decode(data, using: jsonDecoder) else {
            logger?.debug("Undecodable frame")
            return .decodingFailed
        }
        run?.receivedTickSinceConnect = true
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
                try await socket.send(.string(text))
                try await sleep(outboundIntervalNanoseconds)
            } catch {
                guard isCurrent(id) else { return nil }
                return failure(from: error)
            }
        }
        return nil
    }

    // MARK: Failure classification

    private func failure(from error: Error) -> WebSocketTransportFailure {
        if let close = error as? WebSocketClose {
            reportServerClose(close)
            return .closedByServer(code: close.code)
        }
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
