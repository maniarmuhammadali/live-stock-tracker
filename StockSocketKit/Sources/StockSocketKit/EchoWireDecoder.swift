//
//  EchoWireDecoder.swift
//  StockSocketKit
//
//  Created by Muhammad Ali Maniar on 18/10/2026.
//

import Foundation

enum EchoWireDecoder {
    static func decode(_ data: Data, using decoder: JSONDecoder) -> [EchoStockPayload]? {
        if let batch = try? decoder.decode([EchoStockPayload].self, from: data) {
            return batch
        }
        if let single = try? decoder.decode(EchoStockPayload.self, from: data) {
            return [single]
        }
        return nil
    }
}
