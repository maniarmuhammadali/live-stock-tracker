//
//  AppEnvironment.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import Foundation
import StockSocketKit

/// The few things a launch can swap out. Production uses `.live`; UI-test builds substitute a deterministic feed
/// and an in-memory store, so no test-only branch has to live inside `ApplicationBootstrap`.
nonisolated struct AppEnvironment: Sendable {
    var storesInMemory = false
    var transformCatalog: @Sendable ([StockCatalogEntry]) -> [StockCatalogEntry] = { $0 }
    var feedOverride: (@Sendable ([String]) -> any StockEchoFeed)?

    static let live = AppEnvironment()

    /// The only compile-time switch: Release binaries cannot contain the UI-testing environment at all.
    static func forCurrentLaunch() -> AppEnvironment {
        #if DEBUG
        return UITestingEnvironment.make() ?? .live
        #else
        return .live
        #endif
    }
}
