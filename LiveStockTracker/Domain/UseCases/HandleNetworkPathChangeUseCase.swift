//
//  HandleNetworkPathChangeUseCase.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import Foundation

@MainActor
protocol HandleNetworkPathChangeUseCase {
    func execute(_ path: FeedNetworkPath, isInitial: Bool) async
}

struct DefaultHandleNetworkPathChangeUseCase: HandleNetworkPathChangeUseCase {
    let session: any FeedSessionControlling
    let status: any FeedStatusProviding

    func execute(_ path: FeedNetworkPath, isInitial: Bool) async {
        guard path.isSatisfied, !isInitial, status.isStreamingRequested else { return }
        await session.reconnect()
    }
}
