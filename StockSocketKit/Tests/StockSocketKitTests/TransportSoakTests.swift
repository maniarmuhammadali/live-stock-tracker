//
//  TransportSoakTests.swift
//  StockSocketKit
//
//  Created by Muhammad Ali Maniar on 01/05/2026.
//

import XCTest
@testable import StockSocketKit

private actor SocketLedger {
    private(set) var sockets: [ScriptedSocket] = []
    func make(openFails: Bool) -> ScriptedSocket {
        let socket = ScriptedSocket(openFails: openFails)
        sockets.append(socket)
        return socket
    }
}

final class TransportSoakTests: XCTestCase {
    func testReconnectChurnClosesEverySocketAndReleasesTheSession() async {
        let ledger = SocketLedger()
        weak var weakSession: EchoWebSocketSession?
        do {
            let session = EchoWebSocketSession(
                symbols: ["AAPL"],
                backoffPolicy: fastBackoff,
                connectionBuilder: { await ledger.make(openFails: true) },
                sleep: { _ in await Task.yield() }
            )
            weakSession = session
            let stream = await session.wireEventsStream(bufferingPolicy: .unbounded)
            let reader = Task { for await _ in stream {} }
            await session.start()
            await eventually(timeout: 10) { await ledger.sockets.count >= 300 }
            await session.stop()
            await reader.value
        }
        let sockets = await ledger.sockets
        var unclosed = 0
        for socket in sockets where await socket.firstCloseCode == nil { unclosed += 1 }
        XCTAssertEqual(unclosed, 0, "Every socket the driver built must be closed")
        for _ in 0..<50 where weakSession != nil { await Task.yield() }
        XCTAssertNil(weakSession, "Session must not be retained by its own tasks or stream callbacks")
    }

    func testHighVolumeOfSnapshotsIsFullyAccountedFor() async {
        let symbols = (0..<25).map { "S\($0)" }
        let frame = snapshotFrame(symbols: symbols)
        let socket = ScriptedSocket()
        let session = EchoWebSocketSession(symbols: symbols, backoffPolicy: fastBackoff, connectionBuilder: { socket })
        let stream = await session.wireEventsStream(bufferingPolicy: .unbounded)
        let reader = Task { () -> (batches: Int, quotes: Int) in
            var batches = 0, quotes = 0
            for await event in stream {
                if case let .decodedBatch(batch) = event { batches += 1; quotes += batch.count }
            }
            return (batches, quotes)
        }
        await session.start()
        for _ in 0..<5_000 { await socket.deliver(frame) }
        await eventually(timeout: 15) { await session.diagnostics().framesDecoded == 5_000 }
        await session.stop()
        let totals = await reader.value
        XCTAssertEqual(totals.batches, 5_000)
        XCTAssertEqual(totals.quotes, 125_000)
        let diagnostics = await session.diagnostics()
        XCTAssertEqual(diagnostics.eventsDropped, 0)
        XCTAssertEqual(diagnostics.framesDropped, 0)
    }
}
