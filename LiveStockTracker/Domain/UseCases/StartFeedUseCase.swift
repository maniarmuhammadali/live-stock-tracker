//
//  StartFeedUseCase.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import Foundation

@MainActor
protocol StartFeedUseCase {
    func execute() async
}

struct DefaultStartFeedUseCase: StartFeedUseCase {
    let session: any FeedSessionControlling
    let status: any FeedStatusProviding
    let repository: any StockRepositoryProtocol

    func execute() async {
        guard !status.isStreamingRequested else { return }
        repository.resetQuoteOrdering()
        await session.start()
    }
}
