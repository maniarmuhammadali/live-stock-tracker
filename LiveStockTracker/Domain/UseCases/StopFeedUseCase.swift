//
//  StopFeedUseCase.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import Foundation

@MainActor
protocol StopFeedUseCase {
    func execute() async
}

struct DefaultStopFeedUseCase: StopFeedUseCase {
    let session: any FeedSessionControlling

    func execute() async {
        await session.stop()
    }
}
