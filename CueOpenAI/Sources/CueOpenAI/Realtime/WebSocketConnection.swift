import Foundation
import Combine
import os.log

final class WebSocketConnection: NSObject, RealtimeConnectionProtocol, Sendable {
    let events: AsyncThrowingStream<ServerEvent, Error>
    private let stream: AsyncThrowingStream<ServerEvent, Error>.Continuation
    let state: AsyncStream<RealtimeConnectionState>
    private let stateStream: AsyncStream<RealtimeConnectionState>.Continuation
    
    private let messageProcessor: MessageProcessorProtocol
    private let webSocketTask: URLSessionWebSocketTask
    private let receiveTask: Task<Void, Never>
    
    public init(urlRequest: URLRequest, messageProcessor: MessageProcessorProtocol = RealtimeMessageProcessor()) {
        self.messageProcessor = messageProcessor
        (events, stream) = AsyncThrowingStream.makeStream(of: ServerEvent.self)
        (state, stateStream) = AsyncStream.makeStream(of: RealtimeConnectionState.self)
        webSocketTask = URLSession.shared.webSocketTask(with: urlRequest)
    
        let _stream = stream
        let _messageProcessor = messageProcessor
        let _webSocketTask = webSocketTask
        
        receiveTask = Task {
            while !Task.isCancelled {
                do {
                    let message = try await _webSocketTask.receive()
                    switch message {
                        case .data:
                            throw RealtimeClientError.unknownMessageType
                        case .string(let text):
                            guard let data = text.data(using: .utf8) else {
                                throw RealtimeClientError.invalidStringEncoding
                            }
                            _stream.yield(with: Result {try _messageProcessor.decodeEvent(data)})
                        @unknown default:
                            _stream.yield(with: Result.failure(RealtimeClientError.unknownMessageType))
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
    
    public func send(event: ClientEvent) async throws {
        let jsonString = try messageProcessor.encodeEvent(event)
        let message = URLSessionWebSocketTask.Message.string(jsonString)
        try await webSocketTask.send(message)
    }
    
    func muteAudio() {
        // Stub
    }
    
    func unmuteAudio() {
        // Stub
    }
    
    private func updateState(_ newState: RealtimeConnectionState) {
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
