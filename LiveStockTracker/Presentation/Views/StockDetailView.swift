//
//  StockDetailView.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import SwiftUI

struct StockDetailView: View {
    private let repository: any StockRepositoryProtocol
    private let symbol: String

    @State private var model: StockDetailViewModel

    init(repository: any StockRepositoryProtocol, feedStatus: any FeedStatusProviding, symbol: String) {
        self.repository = repository
        self.symbol = symbol
        _model = State(initialValue: StockDetailViewModel(repository: repository, feedStatus: feedStatus, symbol: symbol))
    }

    var body: some View {
        Group {
            if let uiModel = model.uiModel {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header(uiModel: uiModel)

                        priceSection(uiModel: uiModel)

                        figuresSection(uiModel: uiModel)

                        Text(uiModel.descriptionText)
                            .accessibilityIdentifier(AccessibilityID.detailDescription)
                            .font(.body)
                            .foregroundStyle(palette.secondaryText)
                            .padding(.top, 8)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                }
                .opacity(uiModel.stalePresentation ? palette.staleOpacity : 1)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel(Text("detail.loading"))
                    .accessibilityIdentifier(AccessibilityID.detailLoading)
            }
        }
        .background(palette.screenBackground)
        .navigationTitle(Text(symbol))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await model.activate()
        }
        .onDisappear {
            model.deactivate()
        }
    }

    @Environment(\.stockPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private func header(uiModel: StockDetailUIModel) -> some View {
        HStack(alignment: .center, spacing: 14) {
            StockSymbolAvatarView(symbol: uiModel.symbol, companyName: uiModel.companyName, diameter: 56, palette: palette)

            VStack(alignment: .leading, spacing: 8) {
                Text(uiModel.companyName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.primaryText)

                Text(uiModel.symbol)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(palette.groupedSurface)
                    .clipShape(Capsule())
                    .foregroundStyle(palette.secondaryText)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(AccessibilityID.detailHeader)
    }

    private func priceSection(uiModel: StockDetailUIModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("detail.last_price")
                .accessibilityIdentifier(AccessibilityID.detailLastPriceLabel)
                .font(.footnote)
                .foregroundStyle(palette.secondaryText)

            Text(uiModel.lastPriceText)
                .accessibilityIdentifier(AccessibilityID.detailPrice)
                .contentTransition(.numericText())
                .font(.largeTitle.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(uiModel.movementPositive ? palette.positive : palette.negative)

            Text("detail.movement")
                .font(.footnote)
                .foregroundStyle(palette.secondaryText)

            HStack(spacing: 8) {
                Image(systemName: uiModel.movementPositive ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .font(.caption.weight(.bold))

                Text(uiModel.movementLine)
                    .accessibilityIdentifier(AccessibilityID.detailMovement)
                    .font(.headline.monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .foregroundStyle(uiModel.movementPositive ? palette.positive : palette.negative)
        }
        .accessibilityElement(children: .contain)
    }

    private func figuresSection(uiModel: StockDetailUIModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("detail.key_figures")
                .font(.headline)
                .foregroundStyle(palette.primaryText)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 0) {
                figureRow(
                    title: "detail.previous_close", valueText: uiModel.previousCloseText, emphasisPositive: nil,
                    identifier: AccessibilityID.detailPreviousClose
                )
                Divider()
                figureRow(
                    title: "detail.day_change", valueText: uiModel.dayChangeText, emphasisPositive: uiModel.movementPositive,
                    identifier: AccessibilityID.detailDayChange
                )
                Divider()
                figureRow(
                    title: "detail.day_change_pct",
                    valueText: uiModel.dayChangePercentText,
                    emphasisPositive: uiModel.movementPositive,
                    identifier: AccessibilityID.detailDayChangePercent
                )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(palette.groupedSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .accessibilityElement(children: .contain)
    }

    private func figureRow(
        title: LocalizedStringResource,
        valueText: String,
        emphasisPositive: Bool?,
        identifier: String
    ) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout())
        return layout {
            Text(title)
                .foregroundStyle(palette.secondaryText)

            if !dynamicTypeSize.isAccessibilitySize { Spacer() }

            Text(valueText)
                .font(.body.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(color(for: emphasisPositive))
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    private func color(for emphasisPositive: Bool?) -> Color {
        guard let emphasisPositive else {
            return palette.primaryText
        }

        return emphasisPositive ? palette.positive : palette.negative
    }
}
