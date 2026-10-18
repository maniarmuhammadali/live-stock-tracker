//
//  BroadcastFanOut.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import Foundation
import Synchronization

/// Continuations are yielded and finished after the lock is released, because termination callbacks take the same lock.
final class BroadcastFanOut<Element: Sendable>: Sendable {
    private let registrations = Mutex<[UUID: AsyncStream<Element>.Continuation]>([:])
    private let dropped = Atomic<Int>(0)

    nonisolated var droppedCount: Int {
        dropped.load(ordering: .relaxed)
    }

    nonisolated var subscriberCount: Int {
        registrations.withLock { $0.count }
    }

    nonisolated func makeStream(
        bufferingPolicy: AsyncStream<Element>.Continuation.BufferingPolicy = .bufferingOldest(64)
    ) -> AsyncStream<Element> {
        AsyncStream(bufferingPolicy: bufferingPolicy) { continuation in
            let id = UUID()
            registrations.withLock { $0[id] = continuation }
            continuation.onTermination = { @Sendable [self] _ in
                registrations.withLock { _ = $0.removeValue(forKey: id) }
            }
        }
    }

    nonisolated func yield(_ element: Element) {
        let snapshot = registrations.withLock { Array($0.values) }
        for continuation in snapshot {
            if case .dropped = continuation.yield(element) {
                dropped.add(1, ordering: .relaxed)
            }
        }
    }

    nonisolated func finishAll() {
        let snapshot = registrations.withLock { registrations -> [AsyncStream<Element>.Continuation] in
            let copied = Array(registrations.values)
            registrations.removeAll()
            return copied
        }
        for continuation in snapshot {
            continuation.finish()
        }
    }
}
