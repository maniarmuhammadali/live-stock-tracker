//
//  StockUIModels.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import Foundation

struct StockRowUIModel: Equatable, Identifiable {
    var id: String { symbol }
    let symbol: String
    let companyName: String
    let priceText: String
    let movementLine: String
    let movementPositive: Bool
    let stalePresentation: Bool
}

struct StockDetailUIModel: Equatable {
    let symbol: String
    let companyName: String
    let descriptionText: String
    let lastPriceText: String
    let movementLine: String
    let movementPositive: Bool
    let previousCloseText: String
    let dayChangeText: String
    let dayChangePercentText: String
    let stalePresentation: Bool
}

enum StockUIMapper {
    static func rowUIModel(catalog: StockCatalogEntry, quote: StockQuote?, stalePresentation: Bool) -> StockRowUIModel {
        guard let quote else {
            return StockRowUIModel(
                symbol: catalog.symbol,
                companyName: catalog.companyName,
                priceText: String(localized: "placeholder.price"),
                movementLine: String(localized: "placeholder.movement"),
                movementPositive: true,
                stalePresentation: stalePresentation
            )
        }

        let priceDecimal = quote.price
        let priceText = CurrencyFormatting.currencyString(for: priceDecimal)

        let changeDecimal = quote.dayChange

        let percentDecimal = quote.dayChangePercent

        let movementLine = movementSummary(change: changeDecimal, percent: percentDecimal)
        let movementPositive = changeDecimal >= 0

        return StockRowUIModel(
            symbol: catalog.symbol,
            companyName: catalog.companyName,
            priceText: priceText,
            movementLine: movementLine,
            movementPositive: movementPositive,
            stalePresentation: stalePresentation
        )
    }

    static func detailUIModel(catalog: StockCatalogEntry, quote: StockQuote?, stalePresentation: Bool) -> StockDetailUIModel {
        guard let quote else {
            return StockDetailUIModel(
                symbol: catalog.symbol,
                companyName: catalog.companyName,
                descriptionText: catalog.descriptionText,
                lastPriceText: String(localized: "placeholder.price"),
                movementLine: String(localized: "placeholder.movement"),
                movementPositive: true,
                previousCloseText: String(localized: "placeholder.price"),
                dayChangeText: String(localized: "placeholder.price"),
                dayChangePercentText: String(localized: "placeholder.price"),
                stalePresentation: stalePresentation
            )
        }

        let priceDecimal = quote.price
        let previousDecimal = quote.previousClose

        let changeDecimal = quote.dayChange
        let percentDecimal = quote.dayChangePercent

        return StockDetailUIModel(
            symbol: catalog.symbol,
            companyName: catalog.companyName,
            descriptionText: catalog.descriptionText,
            lastPriceText: CurrencyFormatting.currencyString(for: priceDecimal),
            movementLine: movementSummary(change: changeDecimal, percent: percentDecimal),
            movementPositive: changeDecimal >= 0,
            previousCloseText: CurrencyFormatting.currencyString(for: previousDecimal),
            dayChangeText: CurrencyFormatting.signedCurrencyString(for: changeDecimal),
            dayChangePercentText: CurrencyFormatting.signedPercentString(for: percentDecimal),
            stalePresentation: stalePresentation
        )
    }

    private static func movementSummary(change: Decimal, percent: Decimal) -> String {
        let changePart = CurrencyFormatting.signedCurrencyString(for: change)
        let percentPart = CurrencyFormatting.signedPercentString(for: percent)
        return "\(changePart) (\(percentPart))"
    }
}
