//
//  Logging.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 18/10/2026.
//
import Foundation

nonisolated enum LogLevel: Sendable {
    case debug
    case info
    case error
}

nonisolated protocol Logging: Sendable {
    nonisolated func log(_ level: LogLevel, _ message: @autoclosure () -> String)
}
