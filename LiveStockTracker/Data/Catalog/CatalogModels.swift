//
//  CatalogModels.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 18/10/2026.
//

import Foundation

struct CatalogRecordDTO: Codable, Sendable {
    let symbol: String
    let companyName: String
    let descriptionText: String
}
