//
//  FakeEchoFeed.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import Foundation
import StockSocketKit

/// Test double: connects, delivers one snapshot, then stays quiet until stopped.
actor FakeEchoFeed: StockEchoFeed {
    private var continuation: AsyncStream<WebSocketPublicEvent>.Continuation?
    private let payloads: [EchoStockPayload]
    private let onFinishedEmitting: (@Sendable () -> Void)?

    init(payloads: [EchoStockPayload], onFinishedEmitting: (@Sendable () -> Void)? = nil) {
        self.payloads = payloads
        self.onFinishedEmitting = onFinishedEmitting
    }

    func eventsStream(
        bufferingPolicy: AsyncStream<WebSocketPublicEvent>.Continuation.BufferingPolicy
    ) -> AsyncStream<WebSocketPublicEvent> {
        AsyncStream(bufferingPolicy: bufferingPolicy) { continuation in
            self.continuation = continuation
        }
    }

    func beginTransport() {
        guard !Task.isCancelled else { return }
        continuation?.yield(.connected)
        if !payloads.isEmpty { continuation?.yield(.decodedBatch(payloads)) }
        onFinishedEmitting?()
    }

    func stopTransport() {
        continuation?.yield(.disconnected(userInitiated: true))
        continuation?.finish()
        continuation = nil
    }

    func requestReconnect() {}

    func applyOutboundSuspension(_ suspended: Bool) {}
}
