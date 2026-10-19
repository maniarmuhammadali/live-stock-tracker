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
        Group {
            if let url = StockSymbolAvatar.logoURL(forSymbol: symbol) {
                AsyncImage(url: url) { phase in
                    if case let .success(image) = phase {
                        image
                            .resizable()
                            .scaledToFit()
                            .padding(diameter * 0.16)
                            .frame(width: diameter, height: diameter)
                            .background(Color.white)
                    } else {
                        initials
                    }
                }
            } else {
                initials
            }
        }
        .frame(width: diameter, height: diameter)
        .background(StockSymbolAvatar.accentFill(forSymbol: symbol))
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var initials: some View {
        Text(StockSymbolAvatar.initialLetters(symbol: symbol, companyName: companyName))
            .font(.system(size: diameter * 0.42, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.92))
    }
}

private enum StockSymbolAvatar {
    private static let companyDomains: [String: String] = [
        "AAPL": "apple.com",
        "GOOG": "google.com",
        "TSLA": "tesla.com",
        "AMZN": "amazon.com",
        "MSFT": "microsoft.com",
        "NVDA": "nvidia.com",
        "META": "meta.com",
        "NFLX": "netflix.com",
        "CRM": "salesforce.com",
        "ORCL": "oracle.com",
        "ADBE": "adobe.com",
        "SPOT": "spotify.com",
        "AMD": "amd.com",
        "INTC": "intel.com",
        "IBM": "ibm.com",
        "SAP": "sap.com",
        "NOW": "servicenow.com",
        "SNOW": "snowflake.com",
        "PYPL": "paypal.com",
        "SHOP": "shopify.com",
        "MU": "micron.com",
        "QCOM": "qualcomm.com",
        "BAC": "bankofamerica.com",
        "DIS": "disney.com",
        "KO": "coca-cola.com"
    ]

    static func logoURL(forSymbol symbol: String) -> URL? {
        guard let domain = companyDomains[symbol.uppercased()] else { return nil }
        var components = URLComponents(string: "https://www.google.com/s2/favicons")
        components?.queryItems = [
            URLQueryItem(name: "sz", value: "128"),
            URLQueryItem(name: "domain", value: domain)
        ]
        return components?.url
    }

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
