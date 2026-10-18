//
//  AppDependencies.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import Foundation

/// Everything the UI is allowed to reach, assembled once at launch.
@MainActor
struct AppDependencies {
    let repository: any StockRepositoryProtocol
    let feedStatus: any FeedStatusProviding
    let startFeed: any StartFeedUseCase
    let stopFeed: any StopFeedUseCase
    let retryFeed: any RetryFeedUseCase
    let applySceneActivity: any ApplySceneActivityUseCase
    let handleNetworkPathChange: any HandleNetworkPathChangeUseCase
    let networkObserver: FeedNetworkObserver

    var feedControls: FeedControls {
        FeedControls(status: feedStatus, start: startFeed, stop: stopFeed, retry: retryFeed)
    }
}
