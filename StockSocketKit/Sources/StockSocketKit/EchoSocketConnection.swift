//
//  EchoSocketConnection.swift
//  StockSocketKit
//
//  Created by Muhammad Ali Maniar on 18/10/2026.
//

import Foundation

/// One connection attempt. Closing must unblock open, send, and receive.
protocol EchoSocketConnection: Sendable {
    func open() async throws
    func receive() async throws -> URLSessionWebSocketTask.Message
    func send(_ message: URLSessionWebSocketTask.Message) async throws
    func ping() async throws
    func close(code: URLSessionWebSocketTask.CloseCode, reason: Data?) async
}

actor URLSessionEchoSocketConnection: EchoSocketConnection {
    private let url: URL
    private let tlsHooks: EchoTLSHooks
    private let timeout: UInt64
    private var session: URLSession?
    private var task: URLSessionWebSocketTask?
    private let handshake = WebSocketHandshakeAwaiter()
    private let closeState = WebSocketCloseState()
    private var pendingPings: [UUID: WebSocketHandshakeAwaiter] = [:]
    private var closed = false

    init(url: URL, tlsHooks: EchoTLSHooks, timeout: UInt64) {
        self.url = url
        self.tlsHooks = tlsHooks
        self.timeout = timeout
    }

    func open() async throws {
        guard !closed else { throw CancellationError() }
        let delegate = EchoWebSocketURLSessionDelegate(handshake: handshake, tlsHooks: tlsHooks, closeState: closeState)
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = false
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        let task = session.webSocketTask(with: url)
        self.session = session
        self.task = task
        task.resume()
        let result = await handshake.waitHandshakeResult(timeoutNanoseconds: timeout)
        try Task.checkCancellation()
        guard !closed else { throw CancellationError() }
        try result.get()
    }

    func receive() async throws -> URLSessionWebSocketTask.Message {
        guard let task, !closed else { throw CancellationError() }
        do { return try await task.receive() } catch {
            if let close = peerClosure() { throw close }
            throw error
        }
    }

    func send(_ message: URLSessionWebSocketTask.Message) async throws {
        guard let task, !closed else { throw CancellationError() }
        do { try await task.send(message) } catch {
            if let close = peerClosure() { throw close }
            throw error
        }
    }

    func ping() async throws {
        guard let task, !closed else { throw CancellationError() }
        let id = UUID()
        let waiter = WebSocketHandshakeAwaiter()
        pendingPings[id] = waiter
        defer { pendingPings.removeValue(forKey: id) }
        task.sendPing { error in
            if let error { waiter.completeFailure(error) } else { waiter.completeSuccess() }
        }
        do {
            try await waiter.waitHandshakeResult().get()
            try Task.checkCancellation()
        } catch {
            if let close = peerClosure() { throw close }
            throw error
        }
    }

    private func peerClosure() -> WebSocketClose? {
        if let close = closeState.snapshot() { return close }
        guard let task, !closed, task.closeCode != .invalid else { return nil }
        return WebSocketClose(code: task.closeCode.rawValue, reason: task.closeReason)
    }

    func close(code: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        guard !closed else { return }
        closed = true
        handshake.completeFailure(CancellationError())
        for waiter in pendingPings.values { waiter.completeFailure(CancellationError()) }
        pendingPings.removeAll()
        task?.cancel(with: code, reason: reason)
        session?.finishTasksAndInvalidate()
        task = nil
        session = nil
    }
}

extension EchoSocketConnection {
    func close() async { await close(code: .goingAway, reason: nil) }
}
