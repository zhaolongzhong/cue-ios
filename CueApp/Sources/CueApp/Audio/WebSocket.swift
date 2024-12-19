import Foundation
import Network

/// A WebSocket connection for bi-directional communication
final class WebSocket {
    private var connection: NWConnection?
    private var messageBuffer = Data()
    
    private var onTextCallback: ((WebSocket, String) -> Void)?
    private var onErrorCallback: ((WebSocket, Error) -> Void)?
    
    /// Creates a new WebSocket connection
    /// - Parameter request: The URLRequest to connect with
    init(request: URLRequest) async throws {
        guard let url = request.url else {
            throw WebSocketError.invalidURL
        }
        
        // Create NWConnection parameters
        let wsOptions = NWProtocolWebSocket.Options()
        wsOptions.autoReplyPing = true
        
        var headers = request.allHTTPHeaderFields ?? [:]
        headers["Upgrade"] = "websocket"
        headers["Connection"] = "Upgrade"
        headers["Sec-WebSocket-Version"] = "13"
        headers["Sec-WebSocket-Key"] = generateWebSocketKey()
        
        for (key, value) in headers {
            wsOptions.setAdditionalHeader(key, value: value)
        }
        
        let parameters = NWParameters(tls: .init())
        parameters.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)
        
        // Create connection
        let endpoint = NWEndpoint.url(url)
        let connection = NWConnection(to: endpoint, using: parameters)
        
        // Set up state handler
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.startReceiving()
            case .failed(let error):
                self?.onErrorCallback?(self!, error)
            case .waiting(let error):
                self?.onErrorCallback?(self!, error)
            default:
                break
            }
        }
        
        // Start connection
        connection.start(queue: .global())
        
        // Wait for connection
        try await withCheckedThrowingContinuation { continuation in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    continuation.resume()
                case .failed(let error), .waiting(let error):
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }
        }
        
        self.connection = connection
    }
    
    /// Sends text data over the WebSocket
    /// - Parameter text: The text to send
    func send(_ text: String) async throws {
        try await send(text.data(using: .utf8)!)
    }
    
    /// Sends binary data over the WebSocket
    /// - Parameter data: The data to send
    func send(_ data: Data) async throws {
        guard let connection = connection else {
            throw WebSocketError.notConnected
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let metadata = NWProtocolWebSocket.Metadata(opcode: .binary)
            let context = NWConnection.ContentContext(identifier: "data",
                                                    metadata: [metadata])
            
            connection.send(content: data,
                          contentContext: context,
                          isComplete: true,
                          completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }
    
    /// Sets callback for received text messages
    /// - Parameter callback: The callback to invoke
    func onText(callback: @escaping (WebSocket, String) -> Void) {
        onTextCallback = callback
    }
    
    /// Sets callback for errors
    /// - Parameter callback: The callback to invoke
    func onError(callback: @escaping (WebSocket, Error) -> Void) {
        onErrorCallback = callback
    }
    
    /// Closes the WebSocket connection
    func close() {
        connection?.cancel()
        connection = nil
    }
    
    private func startReceiving() {
        receiveNextMessage()
    }
    
    private func receiveNextMessage() {
        connection?.receiveMessage { [weak self] content, context, isComplete, error in
            if let error = error {
                self?.onErrorCallback?(self!, error)
                return
            }
            
            if let content = content {
                self?.handleReceivedData(content, context: context, isComplete: isComplete)
            }
            
            // Continue receiving
            self?.receiveNextMessage()
        }
    }
    
    private func handleReceivedData(_ data: Data,
                                  context: NWConnection.ContentContext?,
                                  isComplete: Bool) {
        guard let metadata = context?.protocolMetadata.first as? NWProtocolWebSocket.Metadata else {
            return
        }
        
        switch metadata.opcode {
        case .text:
            if let text = String(data: data, encoding: .utf8) {
                onTextCallback?(self, text)
            }
            
        case .binary:
            messageBuffer.append(data)
            if isComplete {
                // Process complete binary message
                messageBuffer.removeAll()
            }
            
        case .ping:
            // Send pong response
            let pongData = data
            let metadata = NWProtocolWebSocket.Metadata(opcode: .pong)
            let context = NWConnection.ContentContext(identifier: "pong",
                                                    metadata: [metadata])
            
            connection?.send(content: pongData,
                           contentContext: context,
                           isComplete: true,
                           completion: .contentProcessed { _ in })
            
        default:
            break
        }
    }
    
    private func generateWebSocketKey() -> String {
        let bytes = (0..<16).map { _ in UInt8.random(in: .min ... .max) }
        return Data(bytes).base64EncodedString()
    }
}

enum WebSocketError: LocalizedError {
    case invalidURL
    case notConnected
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid WebSocket URL"
        case .notConnected:
            return "WebSocket not connected"
        }
    }
}