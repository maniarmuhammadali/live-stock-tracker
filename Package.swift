// swift-tools-version: 6.2
import PackageDescription

// Host-side tests compile the same app logic and tests as Xcode. No copied implementation.
let package = Package(
    name: "LiveStockTrackerVerification",
    platforms: [.macOS(.v15), .iOS(.v18)],
    targets: [
        .target(
            name: "LiveStockTracker",
            path: "LiveStockTracker",
            exclude: ["Assets.xcassets", "Config", "Resources", "LiveStockTrackerApp.swift"],
            sources: ["Domain", "Data", "Infrastructure", "Composition/FeedTransportConfiguration.swift"],
            swiftSettings: [.defaultIsolation(MainActor.self), .swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "LiveStockTrackerTests",
            dependencies: ["LiveStockTracker"],
            path: "LiveStockTrackerTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
