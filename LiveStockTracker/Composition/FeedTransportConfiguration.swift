//
//  FeedTransportConfiguration.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 18/10/2026.
//

import Foundation
import StockSocketKit

/// Centralizes transport tuning and the feed WebSocket endpoint (from Info.plist / xcconfig at build time).
enum FeedTransportConfiguration {

    private nonisolated static let feedWebSocketSchemeKey = "FeedWebSocketScheme"
    private nonisolated static let feedWebSocketHostKey = "FeedWebSocketHostAndPath"

    nonisolated static func makeDefaultSocketURL() -> URL? {
        if let url = socketURLFromMainBundle() {
            return url
        }
        return URL(string: "\(fallbackWebSocketScheme)://\(fallbackWebSocketHostAndPath)")
    }

    private nonisolated static let fallbackWebSocketScheme = "wss"
    private nonisolated static let fallbackWebSocketHostAndPath = "ws.postman-echo.com/raw"

    private nonisolated static func socketURLFromMainBundle() -> URL? {
        guard let info = Bundle.main.infoDictionary else {
            return nil
        }

        guard let scheme = info[feedWebSocketSchemeKey] as? String,
              let hostAndPath = info[feedWebSocketHostKey] as? String,
              scheme.isEmpty == false,
              hostAndPath.isEmpty == false else {
            return nil
        }

        return URL(string: "\(scheme)://\(hostAndPath)")
    }
}
