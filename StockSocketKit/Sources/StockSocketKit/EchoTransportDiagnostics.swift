//
//  EchoTransportDiagnostics.swift
//  StockSocketKit
//
//  Created by Muhammad Ali Maniar on 01/05/2026.
//

import Foundation

/// Point-in-time counters for the session; cheap to read and safe to log or show in a debug screen.
public struct EchoTransportDiagnostics: Sendable, Equatable {
    public var framesDecoded = 0
    public var framesDropped = 0
    public var eventsDropped = 0
    public var reconnects = 0
    public var handshakeFailures = 0
    public var staleDataReconnects = 0
    public var lastTimeToFirstTickMilliseconds: Int?

    public init() {}
}
