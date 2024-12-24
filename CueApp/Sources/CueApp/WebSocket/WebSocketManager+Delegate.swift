import Foundation

extension WebSocketManager {
    nonisolated public func urlSession(_ session: URLSession,
                       webSocketTask: URLSessionWebSocketTask,
                       didOpenWithProtocol protocol: String?) {
            Task { @MainActor in
                AppLog.websocket.debug("WebSocket connection established")
                connectionState = .connected
                reconnectAttempts = 0
                lastPongReceived = Date()
            }
        }

    nonisolated public func urlSession(_ session: URLSession,
                       webSocketTask: URLSessionWebSocketTask,
                       didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
                       reason: Data?) {
            Task { @MainActor in
                let reasonString = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "No reason provided"
                AppLog.websocket.debug("WebSocket connection closed with code: \(closeCode.rawValue), reason: \(reasonString)")

                connectionState = .disconnected

                if shouldReconnect {
                    scheduleReconnection()
                }
            }
        }

    nonisolated public func urlSession(_ session: URLSession,
                       task: URLSessionTask,
                       didCompleteWithError error: Error?) {
            Task { @MainActor in
                if let error = error {
                    AppLog.websocket.error("WebSocket task completed with error: \(error.localizedDescription)")
                    handleError(.connectionFailed(error.localizedDescription))
                } else {
                    AppLog.websocket.debug("WebSocket task completed normally")
                }
            }
        }
}
