//
//  LiveStockTrackerApp.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 17/10/2026.
//

import SwiftData
import SwiftUI

@main
struct LiveStockTrackerApp: App {
    private let bootstrap: ApplicationBootstrap.Phase

    init() {
        bootstrap = ApplicationBootstrap.make()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch bootstrap {
                case let .failed(message):
                    StockMessageView(
                        presentation: message,
                        palette: StockPalette.palette(for: .light)
                    )

                case let .ready(dependencies, container):
                    RootStockTrackerView(dependencies: dependencies)
                        .modelContainer(container)
                }
            }
        }
    }
}
