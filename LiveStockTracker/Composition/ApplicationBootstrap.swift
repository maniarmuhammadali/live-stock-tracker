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
        case failed(MessagePresentation)
        case ready(AppDependencies, container: ModelContainer)
    }

    static func make(logger: Logging = OSLogStockLogger(), environment: AppEnvironment = .forCurrentLaunch()) -> Phase {
        guard let socketURL = FeedTransportConfiguration.makeDefaultSocketURL() else {
            return .failed(MessagePresentation.feedTransportFailure)
        }

        let catalogEntries: [StockCatalogEntry]
        do {
            catalogEntries = environment.transformCatalog(try CatalogLoading.load(bundle: .main, logger: logger))
        } catch {
            return .failed(MessagePresentation.catalogFailure)
        }

        let schema = Schema([PersistedQuote.self])

        let container: ModelContainer
        do {
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: environment.storesInMemory)
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            logger.log(.error, "Model container bootstrap failed \(error.localizedDescription)")
            return .failed(MessagePresentation.persistenceFailure)
        }

        let repository = DefaultStockRepository(
            modelContainer: container,
            catalogEntries: catalogEntries,
            logging: logger
        )
        let coordinator = FeedSessionCoordinator(repository: repository,
            feedBuilder: { symbols in
                let transport: any StockEchoFeed
                if let override = environment.feedOverride {
                    transport = override(symbols)
                } else {
                    transport = EchoWebSocketSession(
                        url: socketURL,
                        symbols: symbols,
                        outboundIntervalNanoseconds: EchoTransportDefaults.outboundIntervalNanoseconds,
                        backoffPolicy: .standard,
                        logger: LoggingEchoBridge(logging: logger)
                    )
                }
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
