// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StockSocketKit",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "StockSocketKit", targets: ["StockSocketKit"])
    ],
    targets: [
        .target(
            name: "StockSocketKit",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "StockSocketKitTests",
            dependencies: ["StockSocketKit"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
