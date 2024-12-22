//
//  ClientStatusService.swift
//

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
    @Published private(set) var clientStatuses: [ClientStatus] = []
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupScribscription()
    }

    private func setupScribscription() {
        webSocketManager.clientStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] clientStatus in
                self?.updateClientStatus(clientStatus)
            }
            .store(in: &cancellables)
    }

    private func updateClientStatus(_ status: ClientStatus) {
        if let existingIndex = clientStatuses.firstIndex(where: { $0.id == status.id }) {
            clientStatuses[existingIndex] = status
        } else {
            clientStatuses.append(status)
        }
    }

    func markClientOffline(_ clientId: String) {
        if let existingIndex = clientStatuses.firstIndex(where: { $0.id == clientId }) {
            let offlineStatus = ClientStatus(
                clientId: clientId,
                assistantId: nil,
                runnerId: nil,
                isOnline: false
            )
            clientStatuses[existingIndex] = offlineStatus
        }
    }
}
