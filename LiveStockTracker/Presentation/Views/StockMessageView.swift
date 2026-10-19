//
//  StockMessageView.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import SwiftUI

struct StockMessageView: View {
    private let presentation: MessagePresentation
    private let palette: StockPalette
    private let onRetry: (() -> Void)?

    init(presentation: MessagePresentation, palette: StockPalette, onRetry: (() -> Void)? = nil) {
        self.presentation = presentation
        self.palette = palette
        self.onRetry = onRetry
    }

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(presentation.title)
            } icon: {
                Image(systemName: presentation.symbolName)
            }
        } description: {
            Text(presentation.message)
        } actions: {
            if presentation.showsRetry, let onRetry {
                Button(action: onRetry) {
                    Text("message.retry")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier(AccessibilityID.messageRetry)
            }
        }
        .foregroundStyle(palette.primaryText)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.screenBackground)
        .accessibilityIdentifier(AccessibilityID.messageView)
    }
}

#Preview("Onboarding") {
    StockMessageView(presentation: .startSocketOnboarding, palette: .palette(for: .light))
}

#Preview("Failure, Arabic RTL") {
    StockMessageView(presentation: .feedTransportFailure, palette: .palette(for: .dark), onRetry: {})
        .environment(\.locale, Locale(identifier: "ar"))
        .environment(\.layoutDirection, .rightToLeft)
}
