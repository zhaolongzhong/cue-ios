import Foundation
import Combine
import Dependencies

extension ClientStatusService: DependencyKey {
    public static let liveValue = ClientStatusService()
}

extension DependencyValues {
    var clientStatusService: ClientStatusService {
        get { self[ClientStatusService.self] }
        set { self[ClientStatusService.self] = newValue }
    }
}

public final class ClientStatusService: ObservableObject, @unchecked Sendable {
    @Dependency(\.webSocketManager) public var webSocketManager
    @Published private(set) var clientStatuses: [String: ClientStatus] = [:]
    private var messageHandlerTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupMessageHandler()
    }

    deinit {
        messageHandlerTask?.cancel()
        messageHandlerTask = nil
    }

    private func setupMessageHandler() {
        messageHandlerTask = Task { [weak self] in
            guard let self else { return }

            for await message in webSocketManager.webSocketMessageStream {
                if case .clientStatus(let status) = message {
                    self.updateClientStatus(status)
                }
            }
        }
    }

    private func updateClientStatus(_ status: ClientStatus) {
        clientStatuses[status.id] = status
    }

    func markClientOffline(_ clientId: String) {
        let offlineStatus = ClientStatus(
            clientId: clientId,
            assistantId: nil,
            runnerId: nil,
            isOnline: false
        )
        clientStatuses[clientId] = offlineStatus
    }

    public func getClientStatus(for assistantId: String?) -> ClientStatus? {
        guard let assistantId = assistantId else { return nil }
        return clientStatuses.values.first { $0.assistantId == assistantId }
    }
}
