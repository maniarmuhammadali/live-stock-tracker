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
            exclude: ["Assets.xcassets", "Config", "Resources", "LiveStockTrackerApp.swift",
                      "Composition/ApplicationBootstrap.swift"],
            sources: ["Domain", "Data", "Infrastructure", "Composition/FeedTransportConfiguration.swift",
                      "Presentation/ViewModels"],
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
