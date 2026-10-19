//
//  MessagePresentationMapperTests.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import XCTest

@testable import LiveStockTracker

final class MessagePresentationMapperTests: XCTestCase {
    func testPersistenceFailedUsesPersistenceCopy() {
        let mapped = MessagePresentationMapper.map(failure: .persistenceFailed)
        XCTAssertEqual(mapped.title, MessagePresentation.persistenceFailure.title)
        XCTAssertEqual(mapped.showsRetry, true)
    }
}
