//
//  WebSocketClose.swift
//  StockSocketKit
//
//  Created by Muhammad Ali Maniar on 18/10/2026.
//

import Foundation
import Synchronization

struct WebSocketClose: Error, Sendable, Equatable {
    let code: Int
    let reason: Data?

    /// A normal close and contract/policy errors need an explicit retry by the user.
    var shouldRetry: Bool {
        [1001, 1005, 1006, 1011, 1012, 1013].contains(code)
    }

    var responseCode: URLSessionWebSocketTask.CloseCode {
        // Never transmit the reserved observation-only status codes 1005, 1006 or 1015.
        guard code != 1005, code != 1006, code != 1015,
              let code = URLSessionWebSocketTask.CloseCode(rawValue: code), code != .invalid else {
            return .goingAway
        }
        return code
    }
}

final class WebSocketCloseState: Sendable {
    private let value = Mutex<WebSocketClose?>(nil)

    func record(_ close: WebSocketClose) {
        value.withLock { if $0 == nil { $0 = close } }
    }

    func snapshot() -> WebSocketClose? {
        value.withLock { $0 }
    }
}
