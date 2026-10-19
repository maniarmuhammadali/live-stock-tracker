//
//  StocksListView.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import SwiftUI

struct StocksListView: View {
    @Bindable private var screenModel: StocksListViewModel
    private let resolvedDark: Bool
    private let toggleAppearance: () -> Void

    @Environment(\.stockPalette) private var palette

    init(screenModel: StocksListViewModel, resolvedDark: Bool, toggleAppearance: @escaping () -> Void) {
        _screenModel = Bindable(screenModel)
        self.resolvedDark = resolvedDark
        self.toggleAppearance = toggleAppearance
    }

    var body: some View {
        Group {
            if let failure = screenModel.failurePresentation {
                StockMessageView(presentation: failure, palette: palette, onRetry: {
                    Task { await screenModel.retryAfterFailure() }
                })
            } else if screenModel.onboardingActive {
                StockMessageView(presentation: .startSocketOnboarding, palette: palette)
            } else {
                List(screenModel.rows) { row in
                    NavigationLink(value: StockNavigationRoute.detail(symbol: row.symbol)) {
                        StockRowView(row: row, palette: palette)
                    }
                    .accessibilityIdentifier(AccessibilityID.row(row.symbol))
                    .accessibilityHint(Text("a11y.stock_row.hint"))
                }
                .listStyle(.plain)
                .animation(.easeInOut(duration: 0.2), value: screenModel.rows)
                .accessibilityIdentifier(AccessibilityID.stockList)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if screenModel.isPersistenceDegraded {
                PersistenceWarningBanner(palette: palette)
            }
        }
        .navigationTitle(Text("app.title"))
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                ConnectionIndicatorView(state: screenModel.connectionState, palette: palette)
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(action: toggleAppearance) {
                    Image(systemName: resolvedDark ? "moon.fill" : "moon")
                }
                .accessibilityIdentifier(AccessibilityID.themeToggle)
                .accessibilityLabel(Text("a11y.theme_toggle"))

                sortMenu

                Button {
                    Task {
                        if screenModel.isStreamingRequested {
                            await screenModel.stopStreaming()
                        } else {
                            await screenModel.startStreaming()
                        }
                    }
                } label: {
                    Image(systemName: screenModel.isStreamingRequested ? "stop.fill" : "play.fill")
                }
                .accessibilityIdentifier(AccessibilityID.feedToggle)
                .accessibilityLabel(
                    screenModel.isStreamingRequested ? Text("a11y.feed_stop") : Text("a11y.feed_start")
                )
            }
        }
    }

    /// Two sort fields, each with its own direction: the field picker and the direction picker are independent.
    private var sortMenu: some View {
        Menu {
            Picker(selection: $screenModel.sortOption.field) {
                ForEach(SortField.allCases) { field in
                    Text(field.title)
                        .tag(field)
                        .accessibilityIdentifier(AccessibilityID.sortField(field.rawValue))
                }
            } label: {
                Text("sort.field.title")
            }
            .pickerStyle(.inline)

            Picker(selection: $screenModel.sortOption.direction) {
                ForEach(SortDirection.allCases) { direction in
                    Text(direction.title)
                        .tag(direction)
                        .accessibilityIdentifier(AccessibilityID.sortDirection(direction.rawValue))
                }
            } label: {
                Text("sort.direction.title")
            }
            .pickerStyle(.inline)
        } label: {
            Image(systemName: "arrow.up.arrow.down.circle")
        }
        .accessibilityIdentifier(AccessibilityID.sortMenu)
        .accessibilityLabel(Text("a11y.sort_menu"))
    }
}

private struct PersistenceWarningBanner: View {
    let palette: StockPalette

    var body: some View {
        Label {
            Text("banner.persistence")
                .font(.footnote)
        } icon: {
            Image(systemName: "externaldrive.badge.exclamationmark")
        }
        .foregroundStyle(palette.primaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(palette.groupedSurface)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(AccessibilityID.persistenceBanner)
    }
}

private struct ConnectionIndicatorView: View {
    let state: FeedConnectionState
    let palette: StockPalette

    var body: some View {
        Circle()
            .fill(indicatorColor)
            .frame(width: 10, height: 10)
            .accessibilityElement()
            .accessibilityLabel(Text(state.statusText))
            .accessibilityIdentifier(AccessibilityID.connectionIndicator)
    }

    private var indicatorColor: Color {
        switch state {
        case .connected:
            return palette.positive
        case .connecting, .reconnecting:
            return palette.warning
        case .failed:
            return palette.negative
        case .idle, .stopped:
            return palette.secondaryText.opacity(0.45)
        }
    }
}

private struct StockRowView: View {
    let row: StockRowUIModel
    let palette: StockPalette

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        StockSymbolAvatarView(symbol: row.symbol, companyName: row.companyName, diameter: 42, palette: palette)
                        Text(row.symbol)
                            .font(.headline)
                            .foregroundStyle(palette.primaryText)
                            .fixedSize()
                    }
                    Text(row.companyName)
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    priceAndMovement
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(alignment: .center, spacing: 12) {
                    StockSymbolAvatarView(symbol: row.symbol, companyName: row.companyName, diameter: 42, palette: palette)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.symbol)
                            .font(.headline)
                            .foregroundStyle(palette.primaryText)
                        Text(row.companyName)
                            .font(.subheadline)
                            .foregroundStyle(palette.secondaryText)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 8)
                    priceAndMovement
                }
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .opacity(row.stalePresentation ? palette.staleOpacity : 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(stockRowAccessibilityLabel(row))
    }

    private var priceAndMovement: some View {
        VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: 4) {
            Text(row.priceText)
                .contentTransition(.numericText())
                .font(.headline.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            HStack(spacing: 6) {
                Image(systemName: row.movementPositive ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .font(.caption2.weight(.bold))
                Text(row.movementLine)
                    .font(.caption.monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
        .foregroundStyle(row.movementPositive ? palette.positive : palette.negative)
    }

    private func stockRowAccessibilityLabel(_ row: StockRowUIModel) -> String {
        String(
            localized: "a11y.stock_row.label",
            defaultValue: "\(row.companyName), ticker \(row.symbol). Last price \(row.priceText). \(row.movementLine)",
            comment: "VoiceOver label for a stock row: company, ticker, last price, day change"
        )
    }
}

#Preview("Stock row") {
    StockRowView(
        row: StockRowUIModel(
            symbol: "AAPL",
            companyName: "Apple Inc.",
            priceText: "$242.15",
            movementLine: "+$1.20 (+0.50%)",
            movementPositive: true,
            stalePresentation: false
        ),
        palette: StockPalette.palette(for: .light)
    )
    .padding()
}
