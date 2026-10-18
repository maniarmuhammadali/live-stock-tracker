//
//  LiveStockTrackerApp.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 17/10/2026.
//

import SwiftUI

@main
struct LiveStockTrackerApp: App {
    private let bootstrap: ApplicationBootstrap.Phase

    init() {
        bootstrap = ApplicationBootstrap.make()
    }

    var body: some Scene {
        WindowGroup {
            switch bootstrap {
            case let .failed(message):
                Text(message)
            case let .ready(dependencies):
                FeedPreviewView(dependencies: dependencies)
            }
        }
    }
}

private struct FeedPreviewView: View {
    let dependencies: AppDependencies

    @Environment(\.scenePhase) private var scenePhase
    @State private var quotes: [StockQuote] = []
    @State private var connectionState: FeedConnectionState = .idle

    var body: some View {
        NavigationStack {
            List(quotes) { quote in
                HStack {
                    Text(quote.symbol)
                    Spacer()
                    Text(quote.price.formatted(.number.precision(.fractionLength(2))))
                    Text(quote.dayChange >= 0 ? "▲" : "▼")
                        .foregroundStyle(quote.dayChange >= 0 ? .green : .red)
                }
            }
            .navigationTitle("Stocks")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text(String(describing: connectionState)).font(.caption)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Start") { Task { await dependencies.startFeed.execute() } }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Stop") { Task { await dependencies.stopFeed.execute() } }
                }
            }
        }
        .task {
            for await state in dependencies.feedStatus.connectionEvents() {
                connectionState = state
                print("[feed] connection \(state)")
            }
        }
        .task {
            for await batch in dependencies.repository.quoteBatches() {
                quotes = dependencies.repository.currentMergedQuotes().sorted(by: .default)
                let sample = batch.quotes.prefix(3).map { "\($0.symbol) \($0.price)" }
                print("[feed] batch of \(batch.quotes.count): \(sample.joined(separator: ", ")) ...")
            }
        }
        .task {
            await dependencies.networkObserver.observeChanges(using: dependencies.handleNetworkPathChange)
        }
        .task(id: scenePhase) {
            await dependencies.applySceneActivity.execute(scenePhase == .active ? .active : .inactive)
        }
    }
}
