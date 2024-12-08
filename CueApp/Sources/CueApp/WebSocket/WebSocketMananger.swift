import Foundation
import Combine
import os.log

@MainActor
class WebSocketManager: NSObject, ObservableObject, URLSessionWebSocketDelegate {
    @Published var connectionState: ConnectionState = .disconnected
    @Published var clientStatuses: [ClientStatus] = []

    private let clientId: String
    private let accessToken: String
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    var onMessageReceived: ((MessagePayload) -> Void)?
    var onClientStatusUpdated: ((ClientStatus) -> Void)?

    private var reconnectTimer: Timer?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private let baseReconnectDelay: TimeInterval = 5.0

    // Flag to control reconnection attempts
    private var shouldReconnect: Bool = true
    private let pingInterval: TimeInterval = 30.0 // Protocol-level ping every 60 seconds
    private let pongTimeout: TimeInterval = 40.0  // Slightly more than ping interval
    private var lastPongReceived: Date = Date()
    private let timeoutInterval: TimeInterval = TimeInterval.infinity // No timeout
    private var keepAliveTimer: Timer?

    private var isReconnecting = false
    private let connectionLock = NSLock()

    init(assistantId: String = "") {
        self.clientId = EnvironmentConfig.shared.clientId
        self.accessToken = UserDefaults.standard.string(forKey: "ACCESS_TOKEN_KEY") ?? ""

        // Initialize the URLSession once
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForResource = TimeInterval.infinity
        configuration.waitsForConnectivity = true

        // Need to call super.init before setting up session with self as delegate
        super.init()
        self.session = URLSession(configuration: configuration,
                                        delegate: self,
                                        delegateQueue: nil)
    }

    func connect() {
        connectionLock.lock()
        defer { connectionLock.unlock() }

        AppLog.websocket.debug("Initiating WebSocket connection")
        shouldReconnect = true
        lastPongReceived = Date()

        guard connectionState == .disconnected else {
            AppLog.websocket.debug("Connection already in progress or connected. State: \(self.connectionState.description)")
            return
        }

        // Clear any existing tasks and timers
        cleanupExistingConnection()
        connectionState = .connecting

        let baseWebSocketURL = EnvironmentConfig.shared.baseWebSocketURL
        guard var components = URLComponents(string: baseWebSocketURL) else {
            connectionState = .error(.invalidURL)
            AppLog.websocket.error("Invalid base WebSocket URL.")
            return
        }

        components.path = "\(components.path)/\(clientId)"
        guard let wsURL = components.url else {
            connectionState = .error(.invalidURL)
            return
        }

        var request = URLRequest(url: wsURL)
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        webSocketTask = session?.webSocketTask(with: request)

        // Set up ping timers before connecting
        setupPingTimers()

        // Start receiving messages before resuming the task
        receiveMessage()

        webSocketTask?.resume()
    }

    private func cleanupExistingConnection() {
        keepAliveTimer?.invalidate()
        keepAliveTimer = nil
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }

    private func setupPingTimers() {
        // Invalidate existing timers
        keepAliveTimer?.invalidate()

        // Protocol-level ping timer
        Timer.scheduledTimer(withTimeInterval: pingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self,
                      self.connectionState == .connected else { return }
                self.sendProtocolPing()
            }
        }

        // Keep-alive check timer
        keepAliveTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                let timeSinceLastPong = Date().timeIntervalSince(self.lastPongReceived)
                if timeSinceLastPong > self.pongTimeout {
                    AppLog.websocket.error("No pong received for \(Int(timeSinceLastPong)) seconds. Reconnecting...")
                    self.handleError(.connectionFailed("No pong received"))
                }
            }
        }
    }

    private func sendProtocolPing() {
//        AppLog.websocket.debug("Sending protocol-level ping at \(Date())")
        webSocketTask?.sendPing { [weak self] error in
            Task { @MainActor in
                if let error = error {
                    self?.handleError(.connectionFailed("Protocol ping failed: \(error.localizedDescription)"))
                    AppLog.websocket.error("Protocol-level ping failed: \(error.localizedDescription)")
                } else {
//                    AppLog.websocket.debug("Protocol-level pong received at \(Date())")
                    // Update lastPongReceived since pong was received
                    self?.lastPongReceived = Date()
                }
            }
        }
    }

    func disconnect() {
        AppLog.log.debug("WebSocketManager disconnect")
        shouldReconnect = false
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        keepAliveTimer?.invalidate()
        keepAliveTimer = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        connectionState = .disconnected
        reconnectAttempts = 0 // Reset attempts on manual disconnect
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

    private func handleError(_ error: ConnectionError) {
        Task { @MainActor in
            connectionState = .error(error)

            switch error {
            case .invalidURL:
                AppLog.websocket.error("Invalid WebSocket URL.")
            case .connectionFailed(let description):
                AppLog.websocket.error("WebSocket connection failed: \(description)")
                if description.contains("Socket is not connected") || description.contains("Socket not connected") {
                    cleanupExistingConnection()
                    scheduleReconnection()
                }
            case .receiveFailed(let description):
                AppLog.websocket.error("WebSocket receive failed: \(description)")
                if description.contains("Socket is not connected") || description.contains("Socket not connected") {
                    cleanupExistingConnection()
                    scheduleReconnection()
                }
            }
        }
    }

    private func scheduleReconnection() {
        AppLog.websocket.debug("scheduleReconnection")
        guard !isReconnecting else {
           AppLog.websocket.debug("Reconnection already in progress")
           return
        }

        reconnectTimer?.invalidate()

        guard shouldReconnect, reconnectAttempts < maxReconnectAttempts else {
            AppLog.websocket.error("Max reconnection attempts reached or shouldReconnect is false. Giving up.")
            isReconnecting = false
            return
        }

        isReconnecting = true
        let delay = baseReconnectDelay * pow(2.0, Double(reconnectAttempts))
        reconnectAttempts += 1

        AppLog.websocket.debug("Scheduling reconnection attempt \(self.reconnectAttempts) in \(delay) seconds.")

        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isReconnecting = false
                self?.connect()
            }
       }
   }

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                switch result {
                case .success(let message):
                    switch message {
                    case .string(let text):
                        self.connectionState = .connected
                        self.reconnectAttempts = 0  // Reset attempts on successful message

                        if let data = text.data(using: .utf8) {
                            do {
                                JSONDecoder.debugPrint(data)
                                let eventMessage = try JSONDecoder().decode(EventMessage.self, from: data)
                                self.handleReceivedMessage(eventMessage)
                            } catch {
                                AppLog.websocket.error("Error decoding EventMessage: \(error)")
                            }
                        }

                        // Continue listening only if still connected
                        if self.connectionState == .connected {
                            self.receiveMessage()
                        }

                    case .data(let data):
                        AppLog.websocket.error("Received binary message: \(data)")
                        self.receiveMessage()

                    @unknown default:
                        AppLog.websocket.error("Received unknown message type")
                        self.receiveMessage()
                    }

                case .failure(let error):
                    self.handleError(.receiveFailed(error.localizedDescription))
                }
            }
        }
    }

    private func handleReceivedMessage(_ eventMessage: EventMessage) {
        switch eventMessage.type {
        case .ping:
            // skip, use protocol level ping and pong instead
            return
        case .pong:
            // Received a pong from an unexpected application-level message
            AppLog.websocket.debug("Received unexpected protocol-level pong in application message at \(Date())")
        case .clientConnect, .clientDisconnect, .clientStatus:
            if case .clientEvent(let clientEventPayload) = eventMessage.payload {
                AppLog.websocket.debug("Received client event \(eventMessage.type.rawValue): client id - \(clientEventPayload.clientId)")
                if self.clientId == clientEventPayload.clientId {
                    return
                }
                if let jsonPayload = clientEventPayload.payload {
                    if case .dictionary(let dict) = jsonPayload {
                        let runnerId = dict["runner_id"]?.asString
                        let assistantId = dict["assistant_id"]?.asString
                        let clientStatus = ClientStatus(clientId: clientEventPayload.clientId, assistantId: assistantId, runnerId: runnerId, isOnline: true)
                        debugPrint("Client status:", clientStatus)
                        if let existingIndex = clientStatuses.firstIndex(where: { $0.id == clientEventPayload.clientId }) {
                            clientStatuses[existingIndex] = clientStatus
                        } else {
                            clientStatuses.append(clientStatus)
                        }
                        self.onClientStatusUpdated?(clientStatus)
                    }
                } else if eventMessage.type == EventMessageType.clientDisconnect {
                    if let existingIndex = clientStatuses.firstIndex(where: { $0.id == clientEventPayload.clientId }) {
                        let existing = clientStatuses[existingIndex]
                        let clientStatus = ClientStatus(clientId: clientEventPayload.clientId, assistantId: existing.assistantId, runnerId: existing.runnerId, isOnline: false)
                        clientStatuses[existingIndex] = clientStatus
                        debugPrint("Client status:", clientStatus)
                    } else {
                        let clientStatus = ClientStatus(clientId: clientEventPayload.clientId, assistantId: nil, runnerId: nil, isOnline: false)
                        debugPrint("Client status:", clientStatus)
                        clientStatuses.append(clientStatus)
                    }
                }
            }
        case .assistant, .user:
            if case .message(let messagePayload) = eventMessage.payload {
                AppLog.websocket.debug("Received message(id:\(messagePayload.msgId ?? "")): \(messagePayload.message ?? "")")
                self.onMessageReceived?(messagePayload)
            }
        case .generic, .error:
            if case .genericMessage(let genericPayload) = eventMessage.payload {
                AppLog.websocket.debug("Received generic message: \(genericPayload.message ?? "")")
            }
        }
    }

    // MARK: - URLSessionWebSocketDelegate Methods

    nonisolated func urlSession(_ session: URLSession,
                       webSocketTask: URLSessionWebSocketTask,
                       didOpenWithProtocol protocol: String?) {
            Task { @MainActor in
                AppLog.websocket.debug("WebSocket connection established")
                connectionState = .connected
                reconnectAttempts = 0
                lastPongReceived = Date()
            }
        }

    nonisolated func urlSession(_ session: URLSession,
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

    nonisolated func urlSession(_ session: URLSession,
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
