import Foundation
import Combine
import Dependencies
import os.log

extension WebSocketManager: DependencyKey {
    public static let liveValue = WebSocketManager()
}

extension DependencyValues {
    var webSocketManager: WebSocketManager {
        get { self[WebSocketManager.self] }
        set { self[WebSocketManager.self] = newValue }
    }
}

public final class WebSocketManager: NSObject, URLSessionWebSocketDelegate, @unchecked Sendable {
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
    private var cancellables = Set<AnyCancellable>()

    private var connectionState: ConnectionState = .disconnected {
        didSet {
            AppLog.websocket.debug("Connection state changed to: \(self.connectionState.description)")
            connectionStateSubject.send(connectionState)

        }
    }

    private(set) var lastError: WebSocketError?

    private let connectionStateSubject = PassthroughSubject<ConnectionState, Never>()
    private let eventMessageSubject = CurrentValueSubject<EventMessage?, Never>(nil)
    private let messageSubject = PassthroughSubject<MessagePayload, Never>()
    private let clientStatusSubject = PassthroughSubject<ClientStatus, Never>()

    var connectionStatePublisher: AnyPublisher<ConnectionState, Never> {
        connectionStateSubject.eraseToAnyPublisher()
    }

    var eventMessagePublisher: AnyPublisher<EventMessage, Never> {
        eventMessageSubject
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }

    var messagePublisher: AnyPublisher<MessagePayload, Never> {
            messageSubject.eraseToAnyPublisher()
        }

    var clientStatusPublisher: AnyPublisher<ClientStatus, Never> {
        clientStatusSubject.eraseToAnyPublisher()
    }

    public init(assistantId: String = "") {
        self.clientId = EnvironmentConfig.shared.clientId

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
        super.init()

        setupSubscriptions()
    }

    deinit {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }

    private func setupSubscriptions() {
        eventMessagePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                guard let self = self else { return }
                Task {
                    await self.processEventMessage(message)
                }
            }
            .store(in: &cancellables)
    }

    @MainActor
    func connect() async {
        AppLog.websocket.debug("connect")
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
                let decoder = JSONDecoder()
                let wsMessage = try decoder.decode(EventMessage.self, from: Data(text.utf8))
                await MainActor.run {
                    eventMessageSubject.send(wsMessage)
                }
            } catch {
                await MainActor.run {
                    AppLog.websocket.error("Failed to decode message: \(error.localizedDescription)")
                    lastError = .messageDecodingFailed
                }
            }

        case .data(let data):
            do {
                let decoder = JSONDecoder()
                let wsMessage = try decoder.decode(EventMessage.self, from: data)
                await MainActor.run {
                    eventMessageSubject.send(wsMessage)
                }
            } catch {
                await MainActor.run {
                    AppLog.websocket.error("Failed to decode message: \(error.localizedDescription)")
                    lastError = .messageDecodingFailed
                }
            }

        @unknown default:
            await MainActor.run {
                AppLog.websocket.error("Unknown message type received")
            }
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

    func send(message: String, recipient: String) {
        AppLog.websocket.debug("Sending message: \(message) to recipient: \(recipient)")
        let uuid = UUID().uuidString

        let messagePayload = MessagePayload(
            message: message,
            sender: nil,
            recipient: recipient,
            websocketRequestId: uuid,
            metadata: nil,
            userId: nil,
            payload: nil
        )

        let eventMessage = EventMessage(
            type: .user,
            payload: .message(messagePayload),
            clientId: clientId,
            metadata: nil,
            websocketRequestId: uuid
        )

        guard let jsonData = try? JSONEncoder().encode(eventMessage),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            AppLog.websocket.error("Failed to serialize message")
            return
        }

        send(jsonString)
    }

    private func send(_ jsonString: String) {
        guard connectionState == .connected else {
            AppLog.websocket.error("Attempting to send message while not connected. State: \(self.connectionState.description)")
            handleError(.connectionFailed("Socket not connected"))
            return
        }

        let message = URLSessionWebSocketTask.Message.string(jsonString)
        webSocketTask?.send(message) { [weak self] error in
            Task { @MainActor [weak self] in
                if let error = error {
                    self?.handleError(.connectionFailed(error.localizedDescription))
                    AppLog.websocket.error("WebSocket sending error: \(error)")
                } else {
                    AppLog.websocket.debug("Message sent: \(jsonString)")
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

        // Check reconnection conditions
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

            // If we haven't reached max attempts, try again
            if reconnectAttempts < maxReconnectAttempts {
                await reconnect()
            } else {
                connectionState = .error(.connectionFailed("Failed to reconnect after \(reconnectAttempts) attempts"))
                isReconnecting = false
            }
        }
    }
}

extension WebSocketManager {
    // MARK: - Process Event Message

    func processEventMessage(_ eventMessage: EventMessage) async {
        switch eventMessage.type {
        case .ping:
            break
        case .pong:
            break
        case .clientConnect, .clientDisconnect, .clientStatus:
            if case .clientEvent(let payload) = eventMessage.payload {
                await handleClientEvent(eventMessage, payload)
            }
        case .assistant, .user:
            if case .message(let messagePayload) = eventMessage.payload {
                await MainActor.run {
                    messageSubject.send(messagePayload)
                }
            }
        case .generic, .error:
            if case .genericMessage(let genericPayload) = eventMessage.payload {
                AppLog.websocket.debug("Received generic message: \(genericPayload.message ?? "")")
            }
        }
    }

    private func handleClientEvent(_ event: EventMessage, _ payload: ClientEventPayload) async {
        guard clientId != payload.clientId else { return }

        switch event.type {
        case .clientConnect, .clientStatus:
            if let jsonPayload = payload.payload,
               case .dictionary(let dict) = jsonPayload {
                let clientStatus = ClientStatus(
                    clientId: payload.clientId,
                    assistantId: dict["assistant_id"]?.asString,
                    runnerId: dict["runner_id"]?.asString,
                    isOnline: true
                )
                await MainActor.run {
                    clientStatusSubject.send(clientStatus)
                }
            }
        case .clientDisconnect:
            let clientStatus = ClientStatus(
                clientId: payload.clientId,
                assistantId: nil,
                runnerId: nil,
                isOnline: false
            )
            await MainActor.run {
                clientStatusSubject.send(clientStatus)
            }
        default:
            break
        }
    }
}

extension WebSocketManager {
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
