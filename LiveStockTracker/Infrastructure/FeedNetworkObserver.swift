//
//  FeedNetworkObserver.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import Foundation

@MainActor
struct FeedNetworkObserver {
    let updates: @Sendable () -> AsyncStream<FeedNetworkPath>

    func observeChanges(using handle: any HandleNetworkPathChangeUseCase) async {
        var previousPath: FeedNetworkPath?
        for await path in updates() {
            guard !Task.isCancelled else { return }
            guard path != previousPath else { continue }
            let initial = previousPath == nil
            previousPath = path
            await handle.execute(path, isInitial: initial)
        }
    }
}
