//
//  RetryFeedUseCase.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import Foundation

@MainActor
protocol RetryFeedUseCase {
    func execute() async
}

struct DefaultRetryFeedUseCase: RetryFeedUseCase {
    let session: any FeedSessionControlling
    let repository: any StockRepositoryProtocol

    func execute() async {
        repository.resetQuoteOrdering()
        await session.retry()
    }
}
