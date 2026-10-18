//
//  LoggingEchoBridge.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 18/10/2026.
//

import Foundation
import StockSocketKit

struct LoggingEchoBridge: EchoLogger {
    private let logging: Logging

    init(logging: Logging) {
        self.logging = logging
    }

    nonisolated func debug(_ message: @autoclosure () -> String) {
        logging.log(.debug, message())
    }

    nonisolated func info(_ message: @autoclosure () -> String) {
        logging.log(.info, message())
    }

    nonisolated func error(_ message: @autoclosure () -> String) {
        logging.log(.error, message())
    }
}
