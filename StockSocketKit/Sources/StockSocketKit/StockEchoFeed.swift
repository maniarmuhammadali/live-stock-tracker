//
//  StockEchoFeed.swift
//  StockSocketKit
//
//  Created by Muhammad Ali Maniar on 01/05/2026.
//

import Foundation

public protocol StockEchoFeed: Sendable {
    func eventsStream(
        bufferingPolicy: AsyncStream<WebSocketPublicEvent>.Continuation.BufferingPolicy
    ) async -> AsyncStream<WebSocketPublicEvent>

    /// Starts owned background work and returns. A cancelled caller must not start new work.
    func beginTransport() async
    func stopTransport() async
    /// Invalidate the current link without changing intent or bypassing retry backoff.
    func requestReconnect() async
    func applyOutboundSuspension(_ suspended: Bool) async
}
