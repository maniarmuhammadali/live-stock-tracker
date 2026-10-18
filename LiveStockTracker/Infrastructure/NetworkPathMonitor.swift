//
//  NetworkPathMonitor.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import Foundation
import Network

nonisolated enum NetworkPathMonitor {
    static func updates() -> AsyncStream<FeedNetworkPath> {
        AsyncStream { continuation in
            let monitor = NWPathMonitor()
            let queue = DispatchQueue(label: "com.livestocktracker.reachability.feed")
            monitor.pathUpdateHandler = { path in
                let interfaces = path.availableInterfaces.filter { path.usesInterfaceType($0.type) }
                    .map { "\($0.type):\($0.name)" }.sorted()
                continuation.yield(FeedNetworkPath(isSatisfied: path.status == .satisfied, interfaces: interfaces))
            }
            continuation.onTermination = { _ in monitor.cancel() }
            monitor.start(queue: queue)
        }
    }
}
