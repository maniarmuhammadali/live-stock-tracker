//
//  MessagePresentationMapper.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

nonisolated enum MessagePresentationMapper {
    static func map(failure: FeedFailure) -> MessagePresentation {
        switch failure {
        case .transportUnavailable:
            return .feedTransportFailure
        case .decodingFailed:
            return .feedDecodingFailure
        case .closedByServer:
            return .feedClosedFailure
        case .cancelled:
            return .feedCancelledFailure
        case .persistenceFailed:
            return .persistenceFailure
        }
    }
}
