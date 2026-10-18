//
//  OSLogStockLogger.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 18/10/2026.
//

import Foundation
import os

struct OSLogStockLogger: Logging {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.maniar.LiveStockTracker", category: "app")

    nonisolated func log(_ level: LogLevel, _ message: @autoclosure () -> String) {
        let resolved = message()
        switch level {
        case .debug:
            logger.debug("\(resolved, privacy: .private)")
        case .info:
            logger.info("\(resolved, privacy: .private)")
        case .error:
            logger.error("\(resolved, privacy: .private)")
        }
    }
}
