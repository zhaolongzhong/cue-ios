import Foundation
import Combine
import Dependencies
import os.log

public enum WebSocketMessage: Sendable {
    case clientStatus(ClientStatus)
    case messagePayload(MessagePayload)
    case event(EventMessage)
    case error(WebSocketError)
}

extension WebSocketService: DependencyKey {
    public static let liveValue = WebSocketService()
}

extension DependencyValues {
    var webSocketService: WebSocketService {
        get { self[WebSocketService.self] }
        set { self[WebSocketService.self] = newValue }
    }
}

public final class WebSocketService: NSObject, URLSessionWebSocketDelegate, @unchecked Sendable {
    private let clientId: String
    private let session: URLSession?
    private var webSocketTask: URLSessionWebSocketTask?
    private let maxReconnectAttempts = 5
    private var reconnectAttempts = 0
    private let baseReconnectDelay: TimeInterval = 5.0
    private let pingInterval: TimeInterval = 30.0
    private var lastPongReceived = Date()
    private var isReconnecting = false
    private var backgroundTask: Task<Void, Never>?

    private var connectionState: ConnectionState = .disconnected {
        didSet {
            AppLog.websocket.debug("Connection state changed to: \(self.connectionState.description)")
            connectionStateSubject.send(connectionState)

        }
    }

    private let webSocketMessageSubject = PassthroughSubject<WebSocketMessage, Never>()
    public var webSocketMessagePublisher: AnyPublisher<WebSocketMessage, Never> {
        webSocketMessageSubject.eraseToAnyPublisher()
    }

    private let errorSubject = PassthroughSubject<WebSocketError, Never>()
    public var errorPublisher: AnyPublisher<WebSocketError, Never> {
        errorSubject.eraseToAnyPublisher()
    }

    private let connectionStateSubject = PassthroughSubject<ConnectionState, Never>()
    public var connectionStatePublisher: AnyPublisher<ConnectionState, Never> {
        connectionStateSubject.eraseToAnyPublisher()
    }

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    public init(assistantId: String = "") {
        self.clientId = EnvironmentConfig.shared.clientId

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }

    @MainActor
    func connect() async {
        AppLog.websocket.debug("WebSocket connect")
        guard connectionState != .connected else { return }
        connectionState = .connecting

        do {
            try establishConnection()
        } catch let error as WebSocketError {
            handleError(error)
        } catch {
            handleError(.connectionFailed(error.localizedDescription))
        }
    }

    private func updateLastPongReceived() {
        self.lastPongReceived = Date()
    }

    private func establishConnection() throws {
        guard let accessToken = UserDefaults.standard.string(forKey: "ACCESS_TOKEN_KEY") else {
            throw WebSocketError.unauthorized
        }

        guard let request = buildWebSocketURLRequest(accessToken) else {
            throw WebSocketError.generic(("Invalid url"))
        }

        webSocketTask = session?.webSocketTask(with: request)
        webSocketTask?.resume()

        reconnectAttempts = 0

        startListening()
        startPingTimer()

        connectionState = .connected
        AppLog.websocket.debug("WebSocket connected")
    }

    func disconnect() {
        backgroundTask?.cancel()
        backgroundTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        connectionState = .disconnected
        reconnectAttempts = 0
        AppLog.websocket.debug("WebSocket disconnected")
    }

    // MARK: - Message Handling
    private func startListening() {
        backgroundTask?.cancel()
        backgroundTask = Task {
            guard let task = webSocketTask else { return }
            while !Task.isCancelled {
                do {
                    let message = try await task.receive()
                    await handle(message)
                } catch {
                    handleError(.receiveFailed(error.localizedDescription))
                    break
                }
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message?) async {
        guard let message = message else { return }

        switch message {
        case .string(let text):
            do {
                let eventMessage = try decoder.decode(EventMessage.self, from: Data(text.utf8))
                switch eventMessage.type {
                case .clientConnect, .clientDisconnect, .clientStatus:
                    if let clientStatus = eventMessage.clientStatus {
                        webSocketMessageSubject.send(.clientStatus(clientStatus))
                    }
                case .assistant, .user:
                    if case .message(let messagePayload) = eventMessage.payload {
                        webSocketMessageSubject.send(.messagePayload(messagePayload))
                    }
                case .generic, .error:
                    if case .genericMessage(let genericPayload) = eventMessage.payload {
                        AppLog.websocket.debug("Received generic message: \(genericPayload.message ?? "")")
                    }
                default:
                    break
                }
            } catch {
                await MainActor.run {
                    AppLog.websocket.error("Failed to decode message: \(error.localizedDescription)")
                    errorSubject.send(.messageDecodingFailed)
                }
            }

        case .data:
            AppLog.websocket.error("Unexpected data received")
        @unknown default:
            AppLog.websocket.error("Unknown message type received")
        }
    }

    func handleError(_ error: WebSocketError) {
        Task {
            connectionState = .error(error)

            AppLog.websocket.error("handleError \(error.errorDescription)")

            switch error {
            case .unauthorized:
                break
            case .connectionFailed:
                scheduleReconnection()
            case .messageDecodingFailed:
                break
            case .receiveFailed:
                scheduleReconnection()
            case .generic:
                break
            case .unknown:
                break
            }
        }
    }

    private func sendRawMessage(_ message: String) {
        guard connectionState == .connected else {
            AppLog.websocket.error("Attempting to send message while not connected: \(self.connectionState.description)")
            handleError(.connectionFailed("Socket not connected"))
            return
        }

        let message = URLSessionWebSocketTask.Message.string(message)
        webSocketTask?.send(message) { [weak self] error in
            Task { @MainActor [weak self] in
                if let error = error {
                    self?.handleError(.connectionFailed(error.localizedDescription))
                    AppLog.websocket.error("WebSocket sending error: \(error)")
                }
            }
        }
    }

    // MARK: - Connection Maintenance
    private func startPingTimer() {
        Task {
            while !Task.isCancelled && connectionState == .connected {
                try? await Task.sleep(nanoseconds: UInt64(pingInterval * 1_000_000_000))
                try? await ping()
            }
        }
    }

    private func ping() async throws {
        webSocketTask?.sendPing(pongReceiveHandler: { [weak self] error in
            if let error {
                AppLog.websocket.error("Send ping error. \(String(describing: error))")
            } else {
                Task { [weak self] in
                    self?.updateLastPongReceived()
                }
            }
        })
    }

    func scheduleReconnection() {
        Task { @MainActor in
            await reconnect()
        }
    }

    private func reconnect() async {
        guard !Task.isCancelled else { return }

        guard !isReconnecting else {
            AppLog.websocket.debug("Reconnection already in progress")
            return
        }

        guard reconnectAttempts < maxReconnectAttempts else {
            AppLog.websocket.error("Max reconnection attempts reached. Giving up.")
            isReconnecting = false
            return
        }

        isReconnecting = true

        // Calculate exponential backoff delay
        let delay = min(baseReconnectDelay * pow(2.0, Double(reconnectAttempts)), 32.0) // Cap at 32 seconds
        reconnectAttempts += 1

        AppLog.websocket.debug("Attempting reconnection \(self.reconnectAttempts) in \(delay) seconds")

        do {
            try await Task.sleep(for: .seconds(delay))
            await connect()
            isReconnecting = false
        } catch {
            if error is CancellationError {
                isReconnecting = false
                return
            }

            if reconnectAttempts < maxReconnectAttempts {
                await reconnect()
            } else {
                connectionState = .error(.connectionFailed("Failed to reconnect after \(reconnectAttempts) attempts"))
                isReconnecting = false
            }
        }
    }
}

extension WebSocketService {
    func send(event: ClientEvent) {
        guard let jsonData = try? encoder.encode(event),
              let messageData = String(data: jsonData, encoding: .utf8) else {
            AppLog.websocket.error("Failed to serialize message")
            return
        }

        sendRawMessage(messageData)
    }

    private func buildWebSocketURLRequest(_ accessToken: String) -> URLRequest? {
        guard var components = URLComponents(string: EnvironmentConfig.shared.baseWebSocketURL) else {
            return nil
        }

        components.path = "\(components.path)/\(clientId)"
        guard let wsURL = components.url else {
            return nil
        }

        var request = URLRequest(url: wsURL)
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }
}
