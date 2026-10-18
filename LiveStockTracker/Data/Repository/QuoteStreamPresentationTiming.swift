//
//  QuoteStreamPresentationTiming.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import Foundation

/// Bounded batching and coalescing intervals shared by the repository and presentation layer.
enum QuoteStreamPresentationTiming {
    /// Batches SwiftData writes while ticks are arriving quickly.
    nonisolated static let persistFlushWindow: Duration = .milliseconds(280)

    /// Throttles SwiftUI refreshes during bursty quote updates (list and detail).
    nonisolated static let uiRefreshCoalesce: Duration = .milliseconds(120)

    /// How long to wait before retrying a failed disk write; live prices are unaffected meanwhile.
    nonisolated static let persistRetryDelay: Duration = .seconds(5)
}
