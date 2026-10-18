//
//  EchoHealthPolicy.swift
//  StockSocketKit
//
//  Created by Muhammad Ali Maniar on 01/05/2026.
//

import Foundation

public struct EchoHealthPolicy: Sendable, Equatable {
    public let heartbeatIntervalNanoseconds: UInt64
    public let pongTimeoutNanoseconds: UInt64
    public let sendTimeoutNanoseconds: UInt64
    /// A link that answers pings but delivers no decoded data for this long is considered stale and reconnected.
    public let staleDataTimeoutNanoseconds: UInt64
    /// Undecodable frames are dropped and counted; this many in a row ends the feed as `decodingFailed`.
    public let maxConsecutiveDecodeFailures: Int

    public init(
        heartbeatIntervalNanoseconds: UInt64 = EchoTransportDefaults.heartbeatIntervalNanoseconds,
        pongTimeoutNanoseconds: UInt64 = EchoTransportDefaults.pongTimeoutNanoseconds,
        sendTimeoutNanoseconds: UInt64 = EchoTransportDefaults.sendTimeoutNanoseconds,
        staleDataTimeoutNanoseconds: UInt64 = EchoTransportDefaults.staleDataTimeoutNanoseconds,
        maxConsecutiveDecodeFailures: Int = EchoTransportDefaults.maxConsecutiveDecodeFailures
    ) {
        precondition(heartbeatIntervalNanoseconds > 0 && pongTimeoutNanoseconds > 0 && sendTimeoutNanoseconds > 0)
        precondition(staleDataTimeoutNanoseconds > 0 && maxConsecutiveDecodeFailures > 0)
        self.heartbeatIntervalNanoseconds = heartbeatIntervalNanoseconds
        self.pongTimeoutNanoseconds = pongTimeoutNanoseconds
        self.sendTimeoutNanoseconds = sendTimeoutNanoseconds
        self.staleDataTimeoutNanoseconds = staleDataTimeoutNanoseconds
        self.maxConsecutiveDecodeFailures = maxConsecutiveDecodeFailures
    }
}

/// Closing the connection on expiry/cancellation releases callback-based URLSession operations.
func withSocketDeadline(
    socket: any EchoSocketConnection,
    nanoseconds: UInt64,
    sleep: @escaping @Sendable (UInt64) async throws -> Void,
    operation: @escaping @Sendable () async throws -> Void
) async throws {
    try await withTaskCancellationHandler {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await sleep(nanoseconds)
                try Task.checkCancellation()
                await socket.close(code: .goingAway, reason: nil)
                throw URLError(.timedOut)
            }
            defer { group.cancelAll() }
            try await group.next()
        }
    } onCancel: {
        Task { await socket.close(code: .goingAway, reason: nil) }
    }
}
