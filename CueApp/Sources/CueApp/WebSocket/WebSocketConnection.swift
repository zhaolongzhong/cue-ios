//
//  WebSocketConnection.swift
//  CueApp
//

import Foundation
import Combine
import os.log

public protocol WebSocketConnectionProtocol: Sendable {
    var messages: AsyncThrowingStream<String, Error> { get }
    var state: AsyncStream<ConnectionState> { get }

    func close()
    func send(_ message: String) async throws
    func send<T: Encodable>(_ message: T) async throws
}

public final class WebSocketConnection: NSObject, WebSocketConnectionProtocol, Sendable {
    // Public streams
    public let messages: AsyncThrowingStream<String, Error>
    private let messagesContinuation: AsyncThrowingStream<String, Error>.Continuation
    public let state: AsyncStream<ConnectionState>
    private let stateStream: AsyncStream<ConnectionState>.Continuation

    // Connection objects
    private let webSocketTask: URLSessionWebSocketTask
    private let receiveTask: Task<Void, Never>
    private let pingTask: Task<Void, Never>
    private let pingInterval: TimeInterval

    public init(urlRequest: URLRequest, pingInterval: TimeInterval = 30.0) {
        (messages, messagesContinuation) = AsyncThrowingStream.makeStream(of: String.self)
        (state, stateStream) = AsyncStream.makeStream(of: ConnectionState.self)
        webSocketTask = URLSession.shared.webSocketTask(with: urlRequest)
        self.pingInterval = pingInterval

        let _messagesContinuation = messagesContinuation
        let _webSocketTask = webSocketTask

        // Create the receive task that will run for the lifetime of the connection
        receiveTask = Task {
            while !Task.isCancelled {
                do {
                    let message = try await _webSocketTask.receive()
                    switch message {
                    case .data(let data):
                        // Try to convert data to string
                        if let text = String(data: data, encoding: .utf8) {
                            _messagesContinuation.yield(text)
                        } else {
                            throw WebSocketError.generic("Could not decode data to string")
                        }
                    case .string(let text):
                        _messagesContinuation.yield(text)
                    default:
                        _messagesContinuation.yield(with: .failure(WebSocketError.unknown()))
                    }
                } catch {
                    _messagesContinuation.yield(with: .failure(error))
                }
            }
        }

        let localWebSocketTask = webSocketTask
        let localPingInterval = pingInterval

        // Create a ping task that runs for the lifetime of the connection
        pingTask = Task {
            while !Task.isCancelled {
                do {
                    // Wait for the ping interval
                    try await Task.sleep(for: .seconds(localPingInterval))

                    // Send a ping without capturing self
                    localWebSocketTask.sendPing { error in
                        if let error = error {
                            AppLog.websocket.error("Ping failed: \(error.localizedDescription)")
                        }
                    }
                } catch {
                    // If sleep is interrupted (by cancellation), just exit the loop
                    if Task.isCancelled {
                        break
                    }
                }
            }
        }

        super.init()

        // Set delegate and start the connection
        webSocketTask.delegate = self
        webSocketTask.resume()
        updateState(.connecting)
    }

    deinit {
        close()
    }

    public func close() {
        receiveTask.cancel()
        pingTask.cancel()
        webSocketTask.cancel(with: .goingAway, reason: nil)
        updateState(.disconnected)
        messagesContinuation.finish()
        stateStream.finish()
    }

    private func sendPing() async {
        webSocketTask.sendPing { error in
            if let error = error {
                AppLog.websocket.error("Ping failed: \(error.localizedDescription)")
            }
        }
    }

    public func send(_ message: String) async throws {
        try await webSocketTask.send(.string(message))
    }

    public func send<T: Encodable>(_ message: T) async throws {
        guard let messageData = try? JSONEncoder().encode(message),
              let messageString = String(data: messageData, encoding: .utf8) else {
            throw WebSocketError.generic("Failed to encode message")
        }
        try await webSocketTask.send(.string(messageString))
    }

    private func updateState(_ newState: ConnectionState) {
        stateStream.yield(newState)
    }
}

extension WebSocketConnection: URLSessionWebSocketDelegate {
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        Task { @MainActor in
            updateState(.connected)
            AppLog.websocket.debug("WebSocket connection established")
        }
    }

    public func urlSession(_: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        Task { @MainActor in
            updateState(.disconnected)
            AppLog.websocket.debug("WebSocket connection closed with code: \(closeCode.rawValue)")
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        Task { @MainActor in
            if let error = error {
                updateState(.error(.unknown(error.localizedDescription)))
                AppLog.websocket.error("WebSocket task failed: \(error.localizedDescription)")
            }
        }
    }
}

public enum WebSocketError: Error, Equatable, Sendable {
    case connectionFailed(String)
    case receiveFailed(String)
    case urlInvalid
    case encodingError
    case unauthorized
    case generic(_ message: String? = nil)
    case unknown(_ message: String? = nil)

    var errorDescription: String {
        switch self {
        case .connectionFailed(let message):
            return "Connection Failed: \(message)"
        case .encodingError:
            return "Failed to decode message"
        case .receiveFailed(let message):
            return "Receive Failed: \(message)"
        case .unauthorized:
            return "Unauthorized access"
        case .urlInvalid:
            return "Invalid URL"
        case .generic(let message):
            return message ?? "An error occurred"
        case .unknown(let message):
            return message ?? "An unknown error occurred"
        }
    }
}

public enum ConnectionState: Equatable, Sendable {
    case disconnected
    case connecting
    case connected
    case error(WebSocketError)

    var description: String {
        switch self {
        case .error(let error):
            return "Error: \(error)"
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting"
        case .disconnected:
            return "Disconnected"
        }
    }
}
