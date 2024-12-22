import Foundation
import Combine
import WebRTC
import os.log

final class WebRTCConnection: RealtimeConnectionProtocol, Sendable {
    let events: AsyncThrowingStream<ServerEvent, Error>
    private let stream: AsyncThrowingStream<ServerEvent, Error>.Continuation
    
    let state: AsyncStream<RealtimeConnectionState>
    private let stateStream: AsyncStream<RealtimeConnectionState>.Continuation
    
    private let messageProcessor: MessageProcessorProtocol
    private let webRTCClient: WebRTCClient
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "WebRTCConnection", category: "WebRTCConnection")
    
    public init(urlRequest: URLRequest, messageProcessor: MessageProcessorProtocol = RealtimeMessageProcessor()) {
        (events, stream) = AsyncThrowingStream.makeStream(of: ServerEvent.self)
        (state, stateStream) = AsyncStream.makeStream(of: RealtimeConnectionState.self)
        self.webRTCClient = WebRTCClient()
        self.messageProcessor = messageProcessor
        let _webRTCClient = webRTCClient
        print("inx init")
        Task {
            do {
                try await _webRTCClient.performSignaling(with: urlRequest)
            } catch {
                _webRTCClient.close()
            }
        }
        self.webRTCClient.delegate = self
    }
    
    deinit {
        close()
    }
    
    public func close() {
        webRTCClient.close()
        updateState(.disconnected)
        stream.finish()
        stateStream.finish()
    }
    
    func send(event: ClientEvent) async throws {
        try await webRTCClient.send(event: event)
    }
    
    func muteAudio() {
        self.webRTCClient.muteAudio()
    }
    
    func unmuteAudio() {
        self.webRTCClient.unmuteAudio()
    }
    
    private func updateState(_ newState: RealtimeConnectionState) {
        stateStream.yield(newState)
    }
}

extension WebRTCConnection: WebRTCClientDelegate {
    func webRTCClient(_ client: WebRTCClient, didChangeDataChannelState state: RTCDataChannelState) {
        logger.debug("WebRTCConnection data channel change to state: \(String(describing:state))")
    }
    
    func webRTCClient(_ client: WebRTCClient, didReceiveData data: Data) {
        self.stream.yield(with: Result {try messageProcessor.decodeEvent(data)})
    }
    
    func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState) {
        logger.debug("WebRTCConnection WebRTC connection change to state: \(String(describing:state))")
        switch state {
        case .disconnected, .failed, .closed:
            logger.debug("WebRTCConnection disconnected")
            Task { @MainActor in
                updateState(.disconnected)
            }
        case .connected:
            logger.debug("WebRTCConnection connected")
            Task { @MainActor in
                updateState(.connected)
            }
        case .completed:
            break
        default:
            break
        }
    }
}
