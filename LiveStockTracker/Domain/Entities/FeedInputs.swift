//
//  FeedInputs.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 18/10/2026.
//

import Foundation

nonisolated enum ApplicationSceneActivity: Sendable {
    case active
    case inactive
}

nonisolated struct FeedNetworkPath: Equatable, Sendable {
    let isSatisfied: Bool
    let interfaces: [String]
}
