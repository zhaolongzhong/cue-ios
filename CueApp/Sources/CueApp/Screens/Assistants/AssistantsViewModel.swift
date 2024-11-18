import SwiftUI
import Combine

@MainActor
class AssistantsViewModel: ObservableObject {
    @Published private(set) var assistants: [Assistant] = []
    @Published private(set) var assistantStatuses: [AssistantStatus] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?

    private let assistantService: AssistantService
    private let webSocketStore: WebSocketManagerStore
    private var cancellables = Set<AnyCancellable>()

    init(assistantService: AssistantService = AssistantService(),
         webSocketStore: WebSocketManagerStore) {
        self.assistantService = assistantService
        self.webSocketStore = webSocketStore
        setupClientStatusSubscriptions()
        Task {
            await fetchAssistants()
        }
    }

    private func setupClientStatusSubscriptions() {
        // Subscribe to WebSocket status updates
        webSocketStore.$manager
            .compactMap { $0 }
            .flatMap { manager -> AnyPublisher<[ClientStatus], Never> in
                manager.$clientStatuses
                    .receive(on: DispatchQueue.main)
                    .eraseToAnyPublisher()
            }
            .sink { [weak self] clientStatuses in
                guard let self = self else { return }
                Task {
                    await self.updateAssistantStatuses(assistants: self.assistants, clientStatuses: clientStatuses)
                }

            }
            .store(in: &cancellables)

        // Subscribe to assistants list updates
        assistantService.$assistants
            .sink { [weak self] assistants in
                guard let self = self else { return }
                Task {
                    await self.updateAssistants(with: assistants)
                }

            }
            .store(in: &cancellables)
    }

    private func findUnmatchedClientStatuses(assistants: [Assistant], clientStatuses: [ClientStatus]) -> [ClientStatus] {
        // Filter client statuses where there is no matching assistant
        let unmatchedStatuses = clientStatuses.filter { clientStatus in
            !assistants.contains { assistant in
                assistant.id == clientStatus.assistantId
            }
        }
        return unmatchedStatuses
    }

    private func updateAssistantStatuses(assistants: [Assistant], clientStatuses: [ClientStatus]) async {
        let unmatchedStatuses = findUnmatchedClientStatuses(assistants: assistants, clientStatuses: clientStatuses)
        if !unmatchedStatuses.isEmpty {
            AppLog.log.debug("Found \(unmatchedStatuses.count) client statuses without matching assistants:")
            for status in unmatchedStatuses {
                guard let assistantId = status.assistantId else {
                    AppLog.log.warning("Assistant id is nil for client: \(status.clientId)")
                    continue
                }
                AppLog.log.debug("Client Status ID: \(status.id), Assistant ID: \(String(describing: assistantId))")
                do {
                    let assistant = try await assistantService.getAssistant(id: status.assistantId ?? "")
                    AppLog.log.debug("Retrieved assistant: \(assistant.id)")

                } catch {
                    AppLog.log.error("Error fetching assistant \(assistantId): \(error.localizedDescription)")
                }
            }
        }
        let updatedStatuses = assistantService.assistants.map { assistant in
            let clientStatus = clientStatuses.first { $0.assistantId == assistant.id }
            return AssistantStatus(
                id: assistant.id,
                name: assistant.name,
                clientId: clientStatus?.id ?? "",
                isOnline: clientStatus?.isOnline ?? false,
                avatarUrl: nil,
                description: clientStatus?.runnerId ?? ""
            )
        }
        let sortedStatuses = updatedStatuses.sorted { $0.isOnline && !$1.isOnline }
        assistantStatuses = sortedStatuses
    }

    private func updateAssistants(with assistants: [Assistant]) async {
        self.assistants = assistants
        let clientStatuses = webSocketStore.manager?.clientStatuses ?? []
        await updateAssistantStatuses(assistants: assistants, clientStatuses: clientStatuses)
    }

    func fetchAssistants() async {
        isLoading = true
        error = nil

        do {
            let assistants = try await assistantService.listAssistants()
            await updateAssistants(with: assistants)
        } catch {
            self.error = error
            AppLog.log.error("Error fetching assistants: \(error.localizedDescription)")
        }

        isLoading = false
    }

    func refreshAssistants() {
        Task {
            await fetchAssistants()
        }
    }

    func getClientStatus(for assistant: AssistantStatus) -> ClientStatus? {
        webSocketStore.manager?.clientStatuses.first { $0.clientId == assistant.clientId }
    }

    // MARK: - Assistant Management

    func deleteAssistant(_ assistant: AssistantStatus) async {
        do {
            try await assistantService.deleteAssistant(id: assistant.id)
            await fetchAssistants() // Refresh the list after deletion
        } catch {
            self.error = error
            AppLog.log.error("Error deleting assistant: \(error.localizedDescription)")
        }
    }

    func createDefaultAssistant() async {
        do {
            _ = try await assistantService.createAssistant(name: nil, isPrimary: true)
            await fetchAssistants()
        } catch {
            self.error = error
            AppLog.log.error("Error creating assistant: \(error.localizedDescription)")
        }
    }
}
