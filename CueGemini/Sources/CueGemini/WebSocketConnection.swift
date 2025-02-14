import Foundation
import Combine
import os.log

final class WebSocketConnection: NSObject, LiveAPIConnectionProtocol, Sendable {
    let events: AsyncThrowingStream<ServerMessage, Error>
    private let stream: AsyncThrowingStream<ServerMessage, Error>.Continuation
    let state: AsyncStream<WebsocketConnectionState>
    private let stateStream: AsyncStream<WebsocketConnectionState>.Continuation

    private let webSocketTask: URLSessionWebSocketTask
    private let receiveTask: Task<Void, Never>
    
    public init(urlRequest: URLRequest) {
        (events, stream) = AsyncThrowingStream.makeStream(of: ServerMessage.self)
        (state, stateStream) = AsyncStream.makeStream(of: WebsocketConnectionState.self)
        webSocketTask = URLSession.shared.webSocketTask(with: urlRequest)
    
        let _stream = stream
        let _webSocketTask = webSocketTask
        
        receiveTask = Task {
            while !Task.isCancelled {
                do {
                    let message = try await _webSocketTask.receive()
                    switch message {
                        case .data(let data):
                        _stream.yield(with: Result {
                            try JSONDecoder().decode(ServerMessage.self, from: data)
                        })
                        case .string(let text):
                            guard let data = text.data(using: .utf8) else {
                                throw LiveAPIClientError.encodingError
                            }
                            _stream.yield(with: Result {
                                try JSONDecoder().decode(ServerMessage.self, from: data)
                            })
                        @unknown default:
                            _stream.yield(with: Result.failure(LiveAPIClientError.unknown()))
                    }
                } catch {
                    _stream.yield(with: .failure(error))
                }
            }
        }
        
        super.init()

        webSocketTask.delegate = self
        webSocketTask.resume()
    }
    
    deinit {
        close()
    }
    
    public func close() {
        webSocketTask.cancel(with: .goingAway, reason: nil)
        updateState(.disconnected)
        stream.finish()
        stateStream.finish()
    }

    public func send<T: Encodable>(_ message: T) async throws {
        guard let messageData = try? JSONEncoder().encode(message),
              let messageString = String(data: messageData, encoding: .utf8) else {
            throw LiveAPIClientError.encodingError
        }
        try await webSocketTask.send(.string(messageString))
    }

    func muteAudio() {
        // Stub
    }
    
    func unmuteAudio() {
        // Stub
    }
    
    private func updateState(_ newState: WebsocketConnectionState) {
        stateStream.yield(newState)
    }
}

extension WebSocketConnection: URLSessionWebSocketDelegate {
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        Task { @MainActor in
            updateState(.connected)
        }
    }
    public func urlSession(_: URLSession, webSocketTask _: URLSessionWebSocketTask, didCloseWith _: URLSessionWebSocketTask.CloseCode, reason _: Data?) {
        stream.finish()
        Task { @MainActor in
            updateState(.disconnected)
        }
    }
}
