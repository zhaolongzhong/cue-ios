import SwiftUI
import Combine
import Dependencies

extension WebSocketManagerStore: DependencyKey {
    public static let liveValue = WebSocketManagerStore()
}

extension DependencyValues {
    var webSocketManagerStore: WebSocketManagerStore {
        get { self[WebSocketManagerStore.self] }
        set { self[WebSocketManagerStore.self] = newValue }
    }
}

public final class WebSocketManagerStore: ObservableObject, @unchecked Sendable {
    @Dependency(\.webSocketManager) public var webSocketManager

    @Published public private(set) var connectionState: ConnectionState = .disconnected

    private var cancellables = Set<AnyCancellable>()
    private var lastUserId: String?

    public init() {
        setupAppLifecycleHandlers()
        observeWebSocketManager()
    }

    private func setupAppLifecycleHandlers() {
        NotificationCenter.default.publisher(for: .appDidEnterBackground)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                AppLog.log.debug("WebSocketStore: Disconnecting due to background")
                Task { @MainActor in
                    await self.disconnect()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .appWillEnterForeground)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self, let userId = self.lastUserId else { return }
                AppLog.log.debug("WebSocketStore: Reconnecting from background")
                Task { @MainActor in
                    await self.initialize(for: userId)
                }
            }
            .store(in: &cancellables)
    }

    private func observeWebSocketManager() {
        webSocketManager.$connectionState
            .receive(on: DispatchQueue.main)
            .assign(to: &$connectionState)
    }

    public func initialize(for userId: String) async {
        AppLog.log.debug("WebSocketStore: initialize for userId: \(userId)")
        guard lastUserId != userId else { return }

        lastUserId = userId
        await webSocketManager.connect()
    }

    public func disconnect() async {
        AppLog.log.debug("WebSocketManagerStore: Disconnecting")
        webSocketManager.disconnect()
        connectionState = .disconnected
    }

    public func send(message: String, recipient: String) {
        webSocketManager.send(message: message, recipient: recipient)
    }

    public func addMessageHandler(_ handler: @escaping (MessagePayload) -> Void) {
        webSocketManager.onMessageReceived = handler
    }

    public func removeMessageHandler() {
        webSocketManager.onMessageReceived = nil
    }

    public func getClientStatus(for assistantId: String?) -> ClientStatus? {
        guard let assistantId = assistantId else { return nil }
        return webSocketManager.clientStatuses.first { $0.assistantId == assistantId }
    }

    deinit {
        cancellables.forEach { $0.cancel() }
    }
}
