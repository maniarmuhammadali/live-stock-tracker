//
//  WebSocketPublicEvent.swift
//  StockSocketKit
//
//  Created by Muhammad Ali Maniar on 01/05/2026.
//

import Foundation

public enum WebSocketPublicEvent: Equatable, Sendable {
    case serverClosed(code: Int, reason: String?)
    case connected
    case disconnected(userInitiated: Bool)
    case reconnectScheduled(attempt: Int)
    case decodedBatch([EchoStockPayload])
    case transportFailure(WebSocketTransportFailure)
}

public enum WebSocketTransportFailure: Equatable, Sendable {
    case heartbeatTimedOut
    case sendTimedOut
    case staleData
    case closedByServer(code: Int)
    case handshakeFailed
    case closedUnexpectedly
    case decodingFailed
    case cancelled
}
