//
//  MessagePresentation.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import Foundation

/// Typed, compile-time-checked localized copy for full-screen messages. `LocalizedStringResource` literals are
/// picked up by the String Catalog, so an untranslated or misspelled key can't hide behind a runtime string.
nonisolated struct MessagePresentation: Equatable {
    let title: LocalizedStringResource
    let message: LocalizedStringResource
    let symbolName: String
    let showsRetry: Bool

    static let catalogFailure = MessagePresentation(
        title: "message.catalog_failure.title",
        message: "message.catalog_failure.body",
        symbolName: "exclamationmark.triangle.fill",
        showsRetry: false
    )

    static let persistenceFailure = MessagePresentation(
        title: "message.persistence_failure.title",
        message: "message.persistence_failure.body",
        symbolName: "exclamationmark.triangle.fill",
        showsRetry: true
    )

    static let feedTransportFailure = MessagePresentation(
        title: "message.socket_failure.title",
        message: "message.socket_failure.body",
        symbolName: "wifi.slash",
        showsRetry: true
    )

    static let feedDecodingFailure = MessagePresentation(
        title: "message.decode_failure.title",
        message: "message.decode_failure.body",
        symbolName: "text.badge.xmark",
        showsRetry: true
    )

    static let feedClosedFailure = MessagePresentation(
        title: "message.closed_failure.title",
        message: "message.closed_failure.body",
        symbolName: "bolt.slash.fill",
        showsRetry: true
    )

    static let feedCancelledFailure = MessagePresentation(
        title: "message.cancelled_failure.title",
        message: "message.cancelled_failure.body",
        symbolName: "xmark.circle.fill",
        showsRetry: true
    )

    static let startSocketOnboarding = MessagePresentation(
        title: "message.start_socket.title",
        message: "message.start_socket.body",
        symbolName: "antenna.radiowaves.left.and.right",
        showsRetry: false
    )
}
