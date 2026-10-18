//
//  EchoLogger.swift
//  StockSocketKit
//
//  Created by Muhammad Ali Maniar on 01/05/2026.
//

import Foundation

public protocol EchoLogger: Sendable {
    nonisolated func debug(_ message: @autoclosure () -> String)
    nonisolated func info(_ message: @autoclosure () -> String)
    nonisolated func error(_ message: @autoclosure () -> String)
}
