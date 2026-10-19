//
//  RootStockTrackerView.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import SwiftUI

struct RootStockTrackerView: View {
    private let dependencies: AppDependencies

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    @State private var screenModel: StocksListViewModel
    @State private var prefersDarkAppearance: Bool?

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _screenModel = State(initialValue: StocksListViewModel(
            repository: dependencies.repository, feed: dependencies.feedControls, startsFeedOnLaunch: true
        ))
    }

    var body: some View {
        let paletteScheme: ColorScheme = resolvedDark ? .dark : .light
        let palette = StockPalette.palette(for: paletteScheme)

        NavigationStack {
            StocksListView(
                screenModel: screenModel,
                resolvedDark: resolvedDark,
                toggleAppearance: toggleAppearance
            )
            .navigationDestination(for: StockNavigationRoute.self) { route in
                switch route {
                case let .detail(symbol):
                    StockDetailView(
                        repository: dependencies.repository, feedStatus: dependencies.feedStatus, symbol: symbol
                    )
                }
            }
        }
        .environment(\.stockPalette, palette)
        .preferredColorScheme(preferredSystemScheme)
        .task {
            await screenModel.activate()
        }
        .onDisappear {
            screenModel.deactivate()
        }
        .task {
            await dependencies.networkObserver.observeChanges(using: dependencies.handleNetworkPathChange)
        }
        .task(id: scenePhase) {
            await dependencies.applySceneActivity.execute(scenePhase == .active ? .active : .inactive)
        }
    }

    private var resolvedDark: Bool {
        if let prefersDarkAppearance {
            return prefersDarkAppearance
        }

        return colorScheme == .dark
    }

    private var preferredSystemScheme: ColorScheme? {
        guard let prefersDarkAppearance else {
            return nil
        }

        return prefersDarkAppearance ? .dark : .light
    }

    private func toggleAppearance() {
        if let prefersDarkAppearance {
            self.prefersDarkAppearance = prefersDarkAppearance == false
        } else {
            prefersDarkAppearance = colorScheme == .dark ? false : true
        }
    }
}
