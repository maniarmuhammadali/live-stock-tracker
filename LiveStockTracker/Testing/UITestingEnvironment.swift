//
//  UITestingEnvironment.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

#if DEBUG
import Foundation
import StockSocketKit

/// Debug-only launch environment for XCUITest (`--ui-testing`): deterministic quotes, isolated in-memory store.
/// `--ui-testing-rtl-fixtures` additionally gives AAPL a long Arabic/English name and a negative day change.
nonisolated enum UITestingEnvironment {
    static let flag = "--ui-testing"
    static let rtlFixturesFlag = "--ui-testing-rtl-fixtures"

    static func make(arguments: [String] = ProcessInfo.processInfo.arguments) -> AppEnvironment? {
        guard arguments.contains(flag) else { return nil }
        let rtlFixtures = arguments.contains(rtlFixturesFlag)
        var environment = AppEnvironment()
        environment.storesInMemory = true
        if rtlFixtures {
            environment.transformCatalog = { entries in
                entries.map { entry in
                    guard entry.symbol == "AAPL" else { return entry }
                    return StockCatalogEntry(
                        symbol: entry.symbol,
                        companyName: "الشركة الدولية للتقنيات والخدمات المالية — International Technology Holdings",
                        descriptionText: entry.descriptionText
                    )
                }
            }
        }
        environment.feedOverride = { symbols in
            DeterministicFeed(payloads: symbols.enumerated().map { index, symbol in
                EchoStockPayload(symbol: symbol, price: Double(100 + index),
                                 previousClose: rtlFixtures && symbol == "AAPL" ? 101 : 100,
                                 emittedAtEpoch: 1_700_000_000)
            })
        }
        return environment
    }
}

/// Connects instantly and delivers one snapshot, then stays quiet until stopped.
actor DeterministicFeed: StockEchoFeed {
    private let payloads: [EchoStockPayload]
    private var continuation: AsyncStream<WebSocketPublicEvent>.Continuation?

    init(payloads: [EchoStockPayload]) {
        self.payloads = payloads
    }

    func eventsStream(
        bufferingPolicy: AsyncStream<WebSocketPublicEvent>.Continuation.BufferingPolicy
    ) -> AsyncStream<WebSocketPublicEvent> {
        AsyncStream(bufferingPolicy: bufferingPolicy) { continuation in
            self.continuation = continuation
        }
    }

    func beginTransport() {
        guard !Task.isCancelled else { return }
        continuation?.yield(.connected)
        continuation?.yield(.decodedBatch(payloads))
    }

    func stopTransport() {
        continuation?.yield(.disconnected(userInitiated: true))
        continuation?.finish()
        continuation = nil
    }

    func requestReconnect() {}

    func applyOutboundSuspension(_ suspended: Bool) {}
}
#endif
