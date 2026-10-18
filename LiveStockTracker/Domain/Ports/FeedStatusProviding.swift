//
//  FeedStatusProviding.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 18/10/2026.
//

import Foundation

/// Read side of the feed: what the user asked for and what the connection is doing right now.
/// Queries go through ports like this one; commands go through use cases.
@MainActor
protocol FeedStatusProviding: AnyObject {
    var isStreamingRequested: Bool { get }
    var currentConnectionState: FeedConnectionState { get }
    func connectionEvents() -> AsyncStream<FeedConnectionState>
}
