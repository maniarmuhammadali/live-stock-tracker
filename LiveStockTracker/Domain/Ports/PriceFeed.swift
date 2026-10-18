//
//  PriceFeed.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 18/10/2026.
//

import Foundation

nonisolated enum PriceFeedEvent: Sendable {
    case connection(FeedConnectionState)
    case quotes([StockQuote])
}

/// One feed session. Adapters translate their wire format and failures at this boundary.
@MainActor
protocol PriceFeed: AnyObject {
    func events() async -> AsyncStream<PriceFeedEvent>
    func start() async
    func stop() async
    func reconnect() async
    func setSuspended(_ suspended: Bool) async
}
