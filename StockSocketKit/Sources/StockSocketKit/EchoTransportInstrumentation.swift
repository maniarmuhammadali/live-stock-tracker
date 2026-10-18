//
//  EchoTransportInstrumentation.swift
//  StockSocketKit
//
//  Created by Muhammad Ali Maniar on 01/05/2026.
//

import Foundation

public typealias EchoTLSAuthenticationChallengeHandler = (
    URLAuthenticationChallenge,
    @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
) -> Void

public struct EchoTLSHooks: @unchecked Sendable {
    public var onAuthenticationChallenge: EchoTLSAuthenticationChallengeHandler?

    public init(
        onAuthenticationChallenge: EchoTLSAuthenticationChallengeHandler? = nil
    ) {
        self.onAuthenticationChallenge = onAuthenticationChallenge
    }
}

public struct EchoTransportMetrics: Sendable {
    public var onReconnectSleep: (@Sendable (_ attemptCounter: Int, _ delayNanos: UInt64) -> Void)?

    public var onHandshakeCompleted: (@Sendable (_ success: Bool) -> Void)?

    public var onTerminalTransportFailure: (@Sendable (WebSocketTransportFailure) -> Void)?

    public var onFrameDropped: (@Sendable () -> Void)?

    public var onEventDropped: (@Sendable (WebSocketPublicEvent) -> Void)?

    public var onStaleData: (@Sendable () -> Void)?

    public var onTimeToFirstTick: (@Sendable (_ milliseconds: Int) -> Void)?

    public init(
        onReconnectSleep: (@Sendable (Int, UInt64) -> Void)? = nil,
        onHandshakeCompleted: (@Sendable (Bool) -> Void)? = nil,
        onTerminalTransportFailure: (@Sendable (WebSocketTransportFailure) -> Void)? = nil,
        onFrameDropped: (@Sendable () -> Void)? = nil,
        onEventDropped: (@Sendable (WebSocketPublicEvent) -> Void)? = nil,
        onStaleData: (@Sendable () -> Void)? = nil,
        onTimeToFirstTick: (@Sendable (Int) -> Void)? = nil
    ) {
        self.onReconnectSleep = onReconnectSleep
        self.onHandshakeCompleted = onHandshakeCompleted
        self.onTerminalTransportFailure = onTerminalTransportFailure
        self.onFrameDropped = onFrameDropped
        self.onEventDropped = onEventDropped
        self.onStaleData = onStaleData
        self.onTimeToFirstTick = onTimeToFirstTick
    }
}
