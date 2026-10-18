//
//  WebSocketPublicEventStreamDefaults.swift
//  StockSocketKit
//
//  Created by Muhammad Ali Maniar on 01/05/2026.
//

import Foundation

public enum WebSocketPublicEventStreamDefaults {
    public static let bufferCapacity: Int = 256

    public static var bufferingPolicy: AsyncStream<WebSocketPublicEvent>.Continuation.BufferingPolicy {
        .bufferingOldest(bufferCapacity)
    }
}
