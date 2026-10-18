//
//  EchoPriceFeed.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import Foundation
import StockSocketKit

/// Converts the Postman echo contract into application events. Owns and cancels its translation task.
@MainActor
final class EchoPriceFeed: PriceFeed {
    nonisolated static let maxConsecutiveInvalidBatches = 5
    private let transport: any StockEchoFeed
    private let logging: Logging
    private var translationTask: Task<Void, Never>?

    init(transport: any StockEchoFeed, logging: Logging) {
        self.transport = transport
        self.logging = logging
    }

    deinit { translationTask?.cancel() }

    func events() async -> AsyncStream<PriceFeedEvent> {
        precondition(translationTask == nil, "A feed session has one event consumer")
        let source = await transport.eventsStream(bufferingPolicy: WebSocketPublicEventStreamDefaults.bufferingPolicy)
        let (stream, continuation) = AsyncStream<PriceFeedEvent>.makeStream(bufferingPolicy: .bufferingOldest(64))
        let logging = logging
        let task = Task {
            var mapping = EventMapping(logging: logging)
            defer { continuation.finish() }
            for await event in source {
                guard !Task.isCancelled else { break }
                guard let mapped = mapping.map(event) else { continue }
                continuation.yield(mapped)
                if case .connection(.failed) = mapped { return }
            }
        }
        translationTask = task
        continuation.onTermination = { _ in task.cancel() }
        return stream
    }

    func start() async { await transport.beginTransport() }

    func stop() async {
        translationTask?.cancel()
        await transport.stopTransport()
        await translationTask?.value
    }

    func reconnect() async { await transport.requestReconnect() }
    func setSuspended(_ suspended: Bool) async { await transport.applyOutboundSuspension(suspended) }

    private struct EventMapping {
        let logging: Logging
        var invalidBatchStreak = 0
        var reconnectAttempt = 0

        mutating func map(_ event: WebSocketPublicEvent) -> PriceFeedEvent? {
            switch event {
            case let .serverClosed(code, _):
                logging.log(.info, "WebSocket server close code \(code)")
                return nil
            case .connected:
                reconnectAttempt = 0
                return .connection(.connected)
            case let .disconnected(userInitiated):
                return .connection(userInitiated ? .stopped : .reconnecting(attempt: reconnectAttempt))
            case let .reconnectScheduled(attempt):
                reconnectAttempt = attempt
                return .connection(.reconnecting(attempt: attempt))
            case let .decodedBatch(payloads):
                return mapBatch(payloads)
            case let .transportFailure(failure):
                return .connection(.failed(reason: Self.failure(from: failure)))
            }
        }

        private mutating func mapBatch(_ payloads: [EchoStockPayload]) -> PriceFeedEvent? {
            let quotes = payloads.compactMap { DomainQuoteMapping.quote(from: $0) }
            let invalid = payloads.count - quotes.count
            if invalid > 0 { logging.log(.error, "Skipped \(invalid) unusable quote(s)") }
            invalidBatchStreak = quotes.isEmpty && invalid > 0 ? invalidBatchStreak + 1 : 0
            if invalidBatchStreak >= EchoPriceFeed.maxConsecutiveInvalidBatches {
                return .connection(.failed(reason: .decodingFailed))
            }
            return quotes.isEmpty ? nil : .quotes(quotes)
        }

        private static func failure(from failure: WebSocketTransportFailure) -> FeedFailure {
            switch failure {
            case .cancelled: .cancelled
            case .decodingFailed: .decodingFailed
            case .closedUnexpectedly, .heartbeatTimedOut, .sendTimedOut, .staleData: .transportUnavailable
            case .handshakeFailed, .closedByServer: .closedByServer
            }
        }
    }
}
