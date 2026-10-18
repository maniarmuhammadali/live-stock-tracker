//
//  EchoWebSocketSession+StockEchoFeed.swift
//  StockSocketKit
//
//  Created by Muhammad Ali Maniar on 01/05/2026.
//

import Foundation

extension EchoWebSocketSession: StockEchoFeed {
    public func eventsStream(
        bufferingPolicy: AsyncStream<WebSocketPublicEvent>.Continuation.BufferingPolicy
    ) async -> AsyncStream<WebSocketPublicEvent> {
        wireEventsStream(bufferingPolicy: bufferingPolicy)
    }

    public func beginTransport() async {
        start()
    }

    public func stopTransport() async {
        await stop()
    }

    public func requestReconnect() async {
        await invalidateCurrentConnection()
    }

    public func applyOutboundSuspension(_ suspended: Bool) async {
        setOutboundSuspended(suspended)
    }
}
