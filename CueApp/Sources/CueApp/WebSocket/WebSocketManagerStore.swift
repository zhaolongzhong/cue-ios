import SwiftUI
import Combine

@MainActor
public class WebSocketManagerStore: ObservableObject {
    @Published private(set) var manager: WebSocketManager?
    @Published private(set) var connectionState: ConnectionState = .disconnected
    private var cancellables = Set<AnyCancellable>()
    private var lastUserId: String?

    public init() {
        setupBackgroundHandling()
    }

    private func setupBackgroundHandling() {
        NotificationCenter.default.addObserver(
            forName: .appDidEnterBackground,
            object: nil,
            queue: .main) { [weak self] _ in
                AppLog.log.debug("WebSocketStore: Disconnecting due to background")
                Task { @MainActor [weak self] in
                    self?.disconnect()
                }
        }

        NotificationCenter.default.addObserver(
            forName: .appWillEnterForeground,
            object: nil,
            queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self,
                          let userId = self.lastUserId else { return }
                    AppLog.log.debug("WebSocketStore: Reconnecting from background")
                    self.initialize(for: userId)
                }
        }
    }

    func initialize(for userId: String) {
        AppLog.log.debug("WebSocketStore: initialize")
        guard manager == nil else { return }

        lastUserId = userId
        manager = WebSocketManager()

        manager?.$connectionState
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.connectionState = state
            }
            .store(in: &cancellables)

        Task {
             manager?.connect()
        }
    }

    func disconnect() {
        cancellables.removeAll()
        manager?.disconnect()
        manager = nil
        connectionState = .disconnected
    }

    func send(message: String, recipient: String) {
        manager?.send(message: message, recipient: recipient)
    }

    func addMessageHandler(_ handler: @escaping (MessagePayload) -> Void) {
        manager?.onMessageReceived = handler
    }

    func removeMessageHandler() {
        manager?.onMessageReceived = nil
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
