import Foundation
import Combine
import Dependencies
import os.log

// MARK: - WebSocket Message Definitions

public enum WebSocketMessage: Sendable {
    case clientStatus(ClientStatus)
    case messagePayload(MessagePayload)
    case event(EventMessage)
    case error(WebSocketError)
}

// MARK: - WebSocketService Protocol

public protocol WebSocketServiceProtocol: Sendable {
    var webSocketMessagePublisher: AnyPublisher<WebSocketMessage, Never> { get }
    var errorPublisher: AnyPublisher<WebSocketError, Never> { get }
    var connectionStatePublisher: AnyPublisher<ConnectionState, Never> { get }

    func connect() async
    func disconnect()
    func send(event: EventMessage) throws
}

// MARK: - WebSocketService Implementation

public final class WebSocketService: WebSocketServiceProtocol, DependencyKey, @unchecked Sendable {
    public static let liveValue = WebSocketService()

    private let clientId: String
    private var webSocketConnection: WebSocketConnectionProtocol?
    private var reconnectAttempts = 0
    private var isReconnecting = false
    private var messageTask: Task<Void, Never>?
    private var stateTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private let backoffConfig: ExponentialBackoff.Configuration
    private let pingInterval: TimeInterval

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

    public init(
        assistantId: String = "",
        backoffConfig: ExponentialBackoff.Configuration = .defaultConfig,
        pingInterval: TimeInterval = 30.0
    ) {
        self.clientId = EnvironmentConfig.shared.clientId
        self.backoffConfig = backoffConfig
        self.pingInterval = pingInterval
    }

    @MainActor
    public func connect() async {
        AppLog.websocket.debug("WebSocket connect requested")

        reconnectTask?.cancel()
        reconnectTask = nil

        // Only reset reconnection attempts on explicit connect
        if !isReconnecting {
            reconnectAttempts = 0
        }

        isReconnecting = false

        guard let accessToken = await TokenManager.shared.accessToken else {
            handleError(.unauthorized)
            return
        }

        await createNewConnection(with: accessToken)
    }

    private func createNewConnection(with accessToken: String) async {
        webSocketConnection?.close()

        guard let request = buildWebSocketURLRequest(accessToken) else {
            await handleError(.generic("Invalid URL"))
            return
        }

        // Create a new connection with configured ping interval
        let connection = WebSocketConnection(urlRequest: request, pingInterval: pingInterval)
        self.webSocketConnection = connection

        listenToMessages(from: connection)
        listenToConnectionState(from: connection)
    }

    private func listenToMessages(from connection: WebSocketConnection) {
        messageTask?.cancel()
        messageTask = Task {
            do {
                for try await message in connection.messages {
                    if Task.isCancelled { break }
                    await handleStringMessage(message)
                }
            } catch {
                if !Task.isCancelled {
                    let wsError = error as? WebSocketError ??
                                  WebSocketError.receiveFailed(error.localizedDescription)
                    await handleError(wsError)

                    // If there was an error receiving messages, schedule reconnection
                    scheduleReconnection()
                }
            }
        }
    }

    private func listenToConnectionState(from connection: WebSocketConnection) {
        stateTask?.cancel()
        stateTask = Task {
            for await state in connection.state {
                if Task.isCancelled { break }

                // Forward state to our state publisher
                connectionStateSubject.send(state)

                // Handle error states and disconnections
                switch state {
                case .error(let error):
                    await handleError(error)

                    // Attempt reconnection after error
                    scheduleReconnection()

                case .disconnected:
                    // Only attempt reconnection if it wasn't an explicit disconnect
                    if !isReconnecting {
                        scheduleReconnection()
                    }

                default:
                    break
                }
            }
        }
    }

    public func disconnect() {
        // Cancel all tasks
        messageTask?.cancel()
        messageTask = nil

        stateTask?.cancel()
        stateTask = nil

        reconnectTask?.cancel()
        reconnectTask = nil

        // Close the connection
        webSocketConnection?.close()
        webSocketConnection = nil

        // Reset state
        reconnectAttempts = 0
        isReconnecting = false

        connectionStateSubject.send(.disconnected)
        AppLog.websocket.debug("WebSocket disconnected")
    }

    private func handleStringMessage(_ text: String) async {
        do {
            let eventMessage = try decoder.decode(EventMessage.self, from: Data(text.utf8))
            await handleEventMessage(eventMessage)
        } catch {
            AppLog.websocket.error("Failed to decode message: \(error.localizedDescription)")
            errorSubject.send(.encodingError)
        }
    }

    @MainActor
    private func handleEventMessage(_ eventMessage: EventMessage) async {
        switch eventMessage.type {
        case .clientConnect, .clientDisconnect, .clientStatus:
            handleClientStatusEvent(eventMessage)
        case .assistant, .user:
            handleMessageEvent(eventMessage)
        case .generic, .error:
            handleGenericEvent(eventMessage)
        default:
            break
        }
    }

    private func handleClientStatusEvent(_ eventMessage: EventMessage) {
        if let clientStatus = eventMessage.clientStatus {
            webSocketMessageSubject.send(.clientStatus(clientStatus))
        }
    }

    private func handleMessageEvent(_ eventMessage: EventMessage) {
        if case .message(let messagePayload) = eventMessage.payload {
            webSocketMessageSubject.send(.messagePayload(messagePayload))
        }
    }

    private func handleGenericEvent(_ eventMessage: EventMessage) {
        if case .genericMessage(let genericPayload) = eventMessage.payload {
            AppLog.websocket.debug("Received generic message: \(genericPayload.message ?? "")")
        }
    }

    @MainActor
    private func handleError(_ error: WebSocketError) {
        AppLog.websocket.error("WebSocket error: \(error.errorDescription)")
        errorSubject.send(error)
        connectionStateSubject.send(.error(error))
    }

    private func scheduleReconnection() {
        guard !isReconnecting else {
            AppLog.websocket.debug("Reconnection already in progress")
            return
        }

        // Increment the reconnection attempts - this should happen before calculating delay
        reconnectAttempts += 1

        reconnectTask?.cancel()
        reconnectTask = Task {
            await reconnect()
        }
    }

    private func reconnect() async {
        isReconnecting = true

        // Calculate delay based on the current retry count
        let delay = ExponentialBackoff.calculateDelay(
            retryCount: reconnectAttempts,
            configuration: backoffConfig
        )

        AppLog.websocket.debug("Attempting reconnection \(self.reconnectAttempts) in \(delay) seconds")

        do {
            try await Task.sleep(for: .seconds(delay))

            if !Task.isCancelled {
                await connect()
            }
        } catch {
            // Sleep was cancelled or connection failed
            AppLog.websocket.error("Reconnection attempt interrupted: \(error.localizedDescription)")

            // If the task was cancelled, make sure to reset the reconnection flag
            if Task.isCancelled {
                isReconnecting = false
            }
        }
    }

    public func send(event: EventMessage) throws {
        guard let connection = webSocketConnection else {
            throw WebSocketError.connectionFailed("No active connection")
        }

        guard let jsonData = try? encoder.encode(event),
              let messageData = String(data: jsonData, encoding: .utf8) else {
            AppLog.websocket.error("Failed to serialize message")
            throw WebSocketError.generic("Failed to serialize message")
        }

        Task {
            do {
                try await connection.send(messageData)
            } catch {
                await handleError(.connectionFailed(error.localizedDescription))
                scheduleReconnection()
            }
        }
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

// MARK: - Dependency Extension

extension DependencyValues {
    var webSocketService: WebSocketServiceProtocol {
        get { self[WebSocketServiceKey.self] }
        set { self[WebSocketServiceKey.self] = newValue }
    }
}

enum WebSocketServiceKey: DependencyKey {
    static let liveValue: WebSocketServiceProtocol = WebSocketService()
}
