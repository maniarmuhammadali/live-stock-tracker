//
//  CatalogLoading.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 18/10/2026.
//

import Foundation

private enum CatalogLoadingError: Error {
    case missingResource
    case decodingFailed
}

enum CatalogLoading {
    static func load(bundle: Bundle, logger: Logging) throws -> [StockCatalogEntry] {
        guard let url = bundle.url(forResource: "catalog", withExtension: "json") else {
            logger.log(.error, "catalog.json missing")
            throw CatalogLoadingError.missingResource
        }

        let data = try Data(contentsOf: url)

        do {
            let decoder = JSONDecoder()
            let records = try decoder.decode([CatalogRecordDTO].self, from: data)
            return records.map {
                StockCatalogEntry(symbol: $0.symbol.uppercased(), companyName: $0.companyName, descriptionText: $0.descriptionText)
            }
        } catch {
            logger.log(.error, "catalog decode failed \(error.localizedDescription)")
            throw CatalogLoadingError.decodingFailed
        }
    }
}
