//
//  StockSymbolAvatarView.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import SwiftUI

struct StockSymbolAvatarView: View {
    let symbol: String
    let companyName: String
    let diameter: CGFloat
    let palette: StockPalette

    var body: some View {
        Text(StockSymbolAvatar.initialLetters(symbol: symbol, companyName: companyName))
            .font(.system(size: diameter * 0.42, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.92))
            .frame(width: diameter, height: diameter)
            .background(StockSymbolAvatar.accentFill(forSymbol: symbol))
            .clipShape(Circle())
            .overlay(
                Circle()
                    .strokeBorder(palette.secondaryText.opacity(0.22), lineWidth: 1)
            )
            .accessibilityHidden(true)
    }
}

private enum StockSymbolAvatar {
    static func initialLetters(symbol: String, companyName: String) -> String {
        func firstSignificantLetter(in word: String) -> Character? {
            word.first { $0.isLetter || $0.isNumber }
        }

        let words = companyName
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { !$0.isEmpty }

        let significant = words.filter { firstSignificantLetter(in: $0) != nil }

        if significant.count >= 2,
           let head = firstSignificantLetter(in: significant[0]),
           let tail = firstSignificantLetter(in: significant[1]) {
            return (String(head) + String(tail)).uppercased()
        }

        if let word = significant.first {
            let letters = word.filter { $0.isLetter || $0.isNumber }
            if letters.count >= 2 {
                return String(letters.prefix(2)).uppercased()
            }
            if let lone = letters.first {
                return String(repeating: lone, count: 2).uppercased()
            }
        }

        let ticker = symbol.uppercased().filter { $0.isLetter || $0.isNumber }
        if ticker.count >= 2 {
            return String(ticker.prefix(2))
        }
        if ticker.count == 1 {
            return ticker + ticker
        }

        return "··"
    }

    static func accentFill(forSymbol symbol: String) -> Color {
        var hash: UInt64 = 5381
        for byte in symbol.uppercased().utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        let hue = Double(hash % 320) / 360.0
        return Color(hue: hue, saturation: 0.52, brightness: 0.58)
    }
}
