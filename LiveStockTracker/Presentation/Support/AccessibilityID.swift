//
//  AccessibilityID.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import Foundation

nonisolated enum AccessibilityID {
    // List screen
    static let stockList = "stocks.list"
    static let connectionIndicator = "connection.indicator"
    static let feedToggle = "toolbar.feed_toggle"
    static let themeToggle = "toolbar.theme_toggle"
    static let sortMenu = "toolbar.sort"
    static let persistenceBanner = "banner.persistence"

    static func sortField(_ rawValue: String) -> String { "sort.field.\(rawValue)" }
    static func sortDirection(_ rawValue: String) -> String { "sort.direction.\(rawValue)" }
    static func row(_ symbol: String) -> String { "stock.row.\(symbol)" }

    // Detail screen
    static let detailLoading = "detail.loading"
    static let detailHeader = "detail.header"
    static let detailLastPriceLabel = "detail.last_price_label"
    static let detailPrice = "detail.price"
    static let detailMovement = "detail.movement"
    static let detailPreviousClose = "detail.previous_close"
    static let detailDayChange = "detail.day_change"
    static let detailDayChangePercent = "detail.day_change_pct"
    static let detailDescription = "detail.description"

    // Messages (onboarding, errors)
    static let messageView = "message.view"
    static let messageRetry = "message.retry"
}
