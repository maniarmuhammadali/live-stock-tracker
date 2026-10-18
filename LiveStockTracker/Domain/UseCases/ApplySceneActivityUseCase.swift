//
//  ApplySceneActivityUseCase.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import Foundation

/// The app moved between foreground and background; the feed pauses outbound work while inactive.
@MainActor
protocol ApplySceneActivityUseCase {
    func execute(_ activity: ApplicationSceneActivity) async
}

struct DefaultApplySceneActivityUseCase: ApplySceneActivityUseCase {
    let session: any FeedSessionControlling

    func execute(_ activity: ApplicationSceneActivity) async {
        await session.setSceneActive(activity == .active)
    }
}
