//
//  LiveAPIWebSocketManager+Extensions.swift
//

import Foundation
import AVFoundation
import os.log
import Combine

extension LiveAPIWebSocketManager {

    // MARK: - Send Text Message

    func sendText(_ text: String) async throws {
        logger.debug("Sending text message: \(text)")
        let content = LiveAPIClientContent(client_content: .init(
            turnComplete: true,
            turns: [.init(
                role: "user",
                parts: [.init(text: text)]
            )]
        ))
        try await send(content)
    }
}

// MARK: - URLSessionWebSocketDelegate Implementation

extension LiveAPIWebSocketManager {
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        logger.debug("WebSocket did open with protocol.")
    }

    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        let reasonString = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "No reason provided"
        logger.debug("WebSocket did close with code: \(closeCode.rawValue), reason: \(reasonString)")
    }
}
