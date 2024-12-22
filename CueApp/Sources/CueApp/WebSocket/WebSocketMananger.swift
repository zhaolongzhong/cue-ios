import Foundation
import Combine
import os.log

@MainActor
class WebSocketManager: NSObject, ObservableObject, URLSessionWebSocketDelegate {
    @Published var connectionState: ConnectionState = .disconnected
    @Published var clientStatuses: [ClientStatus] = []

    private let accessToken: String
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private let maxReconnectAttempts = 5
    private let baseReconnectDelay: TimeInterval = 5.0
    private let pingInterval: TimeInterval = 30.0
    private let pongTimeout: TimeInterval = 40.0
    private var keepAliveTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var reconnectTimer: Timer?
    private let timeoutInterval: TimeInterval = TimeInterval.infinity
    private var keepAliveTimer: Timer?
    private var isReconnecting = false
    private let connectionLock = NSLock()

    let clientId: String
    var reconnectAttempts = 0
    var shouldReconnect = true
    var lastPongReceived = Date()

    var onMessageReceived: ((MessagePayload) -> Void)?
    var onClientStatusUpdated: ((ClientStatus) -> Void)?

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
        Task {
            guard connectionState == .disconnected else {
                AppLog.websocket.debug("Already connected or connecting.")
                return
            }

            do {
                try await establishConnection()
                connectionState = .connecting
                shouldReconnect = true
                reconnectAttempts = 0
                await startReceiving()
                await startKeepAlive()
            } catch {
                handleError(.connectionFailed(error.localizedDescription))
                scheduleReconnection()
            }
        }
    }

    private func startKeepAlive() async {
        keepAliveTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(pingInterval * 1_000_000_000))
                guard connectionState == .connected else { continue }

                webSocketTask?.sendPing(pongReceiveHandler: { [weak self] error in
                    if let error {
                        print("inx we get error: \(error)")
                        AppLog.websocket.error("Send ping error. \(String(describing: error))")
                    } else {
                        Task { [weak self] in
                            await self?.updateLastPongReceived()
                        }
                    }
                })
                let pongReceived = lastPongReceived.addingTimeInterval(pongTimeout) > Date()
                if !pongReceived {
                    handleError(.connectionFailed("Pong not received in time"))
                    break
                }
            }
        }
    }

    private func updateLastPongReceived() {
        self.lastPongReceived = Date()
    }

    private func establishConnection() async throws {
        guard var components = URLComponents(string: EnvironmentConfig.shared.baseWebSocketURL) else {
            throw ConnectionError.invalidURL
        }

        components.path = "\(components.path)/\(clientId)"
        guard let wsURL = components.url else {
            throw ConnectionError.invalidURL
        }

        var request = URLRequest(url: wsURL)
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        webSocketTask = session?.webSocketTask(with: request)
        webSocketTask?.delegate = self
        webSocketTask?.resume()

        connectionState = .connecting

        // Await confirmation of connection
        try await waitForConnection()
    }

    private func waitForConnection() async throws {
        // Implement a mechanism to wait until the connectionState is .connected or an error occurs
        // This can be achieved using a continuation or other synchronization methods
        try await withCheckedThrowingContinuation { continuation in
            let checkInterval: TimeInterval = 0.5
            Task {
                while true {
                    if connectionState == .connected {
                        continuation.resume()
                        break
                    } else if case .error(let error) = connectionState {
                        continuation.resume(throwing: error)
                        break
                    }
                    try? await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
                }
            }
        }
    }

    private func cleanupExistingConnection() {
        keepAliveTimer?.invalidate()
        keepAliveTimer = nil
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
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

    func handleError(_ error: ConnectionError) {
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

    private func startReceiving() async {
        receiveTask = Task {
            guard let task = webSocketTask else { return }
            while !Task.isCancelled {
                do {
                    let message = try await task.receive()
                    await handleReceivedMessage(message)
                } catch {
                    handleError(.receiveFailed(error.localizedDescription))
                    break
                }
            }
        }
    }

    func scheduleReconnection() {
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
}
