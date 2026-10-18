//
//  ApplicationBootstrap.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import Foundation
import StockSocketKit
import SwiftData

enum ApplicationBootstrap {
    enum Phase {
        case failed(String)
        case ready(AppDependencies, container: ModelContainer)
    }

    static func make(logger: Logging = OSLogStockLogger()) -> Phase {
        guard let socketURL = FeedTransportConfiguration.makeDefaultSocketURL() else {
            return .failed("The feed URL is missing.")
        }

        let catalogEntries: [StockCatalogEntry]
        do {
            catalogEntries = try CatalogLoading.load(bundle: .main, logger: logger)
        } catch {
            return .failed("catalog.json could not be loaded.")
        }

        let schema = Schema([PersistedQuote.self])

        let container: ModelContainer
        do {
            let configuration = ModelConfiguration(schema: schema)
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            logger.log(.error, "Model container bootstrap failed \(error.localizedDescription)")
            return .failed("Saved prices could not be opened.")
        }

        let repository = DefaultStockRepository(
            modelContainer: container,
            catalogEntries: catalogEntries,
            logging: logger
        )
        let coordinator = FeedSessionCoordinator(repository: repository,
            feedBuilder: { symbols in
                let transport = EchoWebSocketSession(
                    url: socketURL,
                    symbols: symbols,
                    outboundIntervalNanoseconds: EchoTransportDefaults.outboundIntervalNanoseconds,
                    backoffPolicy: .standard,
                    logger: LoggingEchoBridge(logging: logger)
                )
                return EchoPriceFeed(transport: transport, logging: logger)
            }
        )

        let dependencies = AppDependencies(
            repository: repository,
            feedStatus: coordinator,
            startFeed: DefaultStartFeedUseCase(session: coordinator, status: coordinator, repository: repository),
            stopFeed: DefaultStopFeedUseCase(session: coordinator),
            retryFeed: DefaultRetryFeedUseCase(session: coordinator, repository: repository),
            applySceneActivity: DefaultApplySceneActivityUseCase(session: coordinator),
            handleNetworkPathChange: DefaultHandleNetworkPathChangeUseCase(session: coordinator, status: coordinator),
            networkObserver: FeedNetworkObserver(updates: NetworkPathMonitor.updates)
        )
        return .ready(dependencies, container: container)
    }
}
