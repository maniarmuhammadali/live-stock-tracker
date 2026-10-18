//
//  FeedSessionControlling.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 18/10/2026.
//

import Foundation

@MainActor
protocol FeedSessionControlling: AnyObject {
    func start() async
    func stop() async
    func retry() async
    func reconnect() async
    func setSceneActive(_ isActive: Bool) async
}
