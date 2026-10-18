//
//  FeedControls.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import Foundation

@MainActor
struct FeedControls {
    let status: any FeedStatusProviding
    let start: any StartFeedUseCase
    let stop: any StopFeedUseCase
    let retry: any RetryFeedUseCase
}
