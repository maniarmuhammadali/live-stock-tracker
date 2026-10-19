// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "StockTrackerVerification",
    platforms: [.macOS(.v15), .iOS(.v18)],
    dependencies: [
        .package(path: "StockSocketKit"),
    ],
    targets: [
        .target(
            name: "LiveStockTracker",
            dependencies: ["StockSocketKit"],
            path: "LiveStockTracker",
            exclude: ["Assets.xcassets", "Config", "Resources", "Localizable.xcstrings", "LiveStockTrackerApp.swift",
                      "Presentation/Views", "Presentation/Support/StockNavigationRoute.swift",
                      "Presentation/Support/SortOption+Presentation.swift", "Presentation/Support/StockPalette.swift",
                      "Presentation/Support/StockPaletteEnvironment.swift", "Composition/ApplicationBootstrap.swift"],
            sources: ["Domain", "Data", "Infrastructure", "Composition/FeedTransportConfiguration.swift",
                      "Composition/FeedTransportTuning.swift",
                      "Presentation/ViewModels", "Presentation/Support/CurrencyFormatting.swift",
                      "Presentation/Support/StockUIModels.swift", "Presentation/Support/MessagePresentation.swift",
                      "Presentation/Support/MessagePresentationMapper.swift"],
            swiftSettings: [.defaultIsolation(MainActor.self), .swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "LiveStockTrackerTests",
            dependencies: ["LiveStockTracker", "StockSocketKit"],
            path: "LiveStockTrackerTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
