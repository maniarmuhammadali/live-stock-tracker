//
//  WebSocketHandshakeCoordinator.swift
//  StockSocketKit
//
//  Created by Muhammad Ali Maniar on 01/05/2026.
//

import Foundation
import Synchronization

internal final class WebSocketHandshakeAwaiter: Sendable {
    private struct LockedState {
        var result: Result<Void, Error>?
        var waiters: [CheckedContinuation<Result<Void, Error>, Never>] = []
    }

    private let state = Mutex(LockedState())

    func waitHandshakeResult() async -> Result<Void, Error> {
        await withTaskCancellationHandler {
            await registerWaiter()
        } onCancel: {
            self.completeFailure(CancellationError())
        }
    }

    func waitHandshakeResult(timeoutNanoseconds: UInt64) async -> Result<Void, Error> {
        await withTaskGroup(of: Result<Void, Error>.self) { group in
            group.addTask { await self.waitHandshakeResult() }
            group.addTask {
                do {
                    try await Task.sleep(nanoseconds: timeoutNanoseconds)
                    return .failure(URLError(.timedOut))
                } catch {
                    return .failure(error)
                }
            }
            let first = await group.next() ?? .failure(CancellationError())
            group.cancelAll()
            return first
        }
    }

    private func registerWaiter() async -> Result<Void, Error> {
        await withCheckedContinuation { continuation in
            let immediate = state.withLock { locked -> Result<Void, Error>? in
                if let existing = locked.result {
                    return existing
                }
                locked.waiters.append(continuation)
                return nil
            }
            if let immediate {
                continuation.resume(returning: immediate)
            }
        }
    }

    func completeSuccess() {
        finish(.success(()))
    }

    func completeFailure(_ error: Error) {
        finish(.failure(error))
    }

    private func finish(_ outcome: Result<Void, Error>) {
        let toResume = state.withLock { locked -> [CheckedContinuation<Result<Void, Error>, Never>] in
            guard locked.result == nil else {
                return []
            }
            locked.result = outcome
            let copied = locked.waiters
            locked.waiters.removeAll()
            return copied
        }
        for waiter in toResume {
            waiter.resume(returning: outcome)
        }
    }
}

internal final class EchoWebSocketURLSessionDelegate:
    NSObject,
    URLSessionDelegate,
    URLSessionWebSocketDelegate,
    URLSessionTaskDelegate,
    Sendable {
    private let handshake: WebSocketHandshakeAwaiter
    private let tlsHooks: EchoTLSHooks?
    private let closeState: WebSocketCloseState
    private let reportedOpen = Mutex(false)

    init(handshake: WebSocketHandshakeAwaiter, tlsHooks: EchoTLSHooks?, closeState: WebSocketCloseState) {
        self.handshake = handshake
        self.tlsHooks = tlsHooks
        self.closeState = closeState
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard let handler = tlsHooks?.onAuthenticationChallenge else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        handler(challenge, completionHandler)
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        reportedOpen.withLock { $0 = true }
        handshake.completeSuccess()
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        let close = WebSocketClose(code: closeCode.rawValue, reason: reason)
        closeState.record(close)
        if !reportedOpen.withLock({ $0 }) { handshake.completeFailure(close) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if !reportedOpen.withLock({ $0 }) {
            handshake.completeFailure(error ?? URLError(.cannotConnectToHost))
        }
    }
}
