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

public final class ClientStatusService: ObservableObject, Cleanable, @unchecked Sendable {
    @Dependency(\.webSocketService) public var webSocketService
    @Published private(set) var clientStatuses: [String: ClientStatus] = [:]
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupMessageHandler()
    }

    private func setupMessageHandler() {
        webSocketService.webSocketMessagePublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] message in
                    if case .clientStatus(let status) = message {
                        self?.updateClientStatus(status)
                    }
                }
                .store(in: &cancellables)
    }

    private func updateClientStatus(_ status: ClientStatus) {
        if let assistantId = status.assistantId {
            clientStatuses[assistantId] = status
        } else {
            clientStatuses[status.id] = status
        }
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

    func getClientStatus(for assistantId: String?) -> ClientStatus? {
        guard let assistantId = assistantId else { return nil }
        return clientStatuses.values.first { $0.assistantId == assistantId }
    }

    func cleanup() async {
        cancellables.removeAll()
        clientStatuses.removeAll()
    }
}
