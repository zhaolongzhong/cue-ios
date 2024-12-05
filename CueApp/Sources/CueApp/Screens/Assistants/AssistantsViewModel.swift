import SwiftUI
import Combine

@MainActor
public class AssistantsViewModel: ObservableObject {
    @Published private(set) var assistants: [Assistant] = []
    @Published private(set) var assistantStatuses: [AssistantStatus] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    @Published var primaryAssistant: AssistantStatus?
    @Published var assistantToDelete: AssistantStatus?

    private let assistantService: AssistantService
    let webSocketManagerStore: WebSocketManagerStore
    private var cancellables = Set<AnyCancellable>()

    init(assistantService: AssistantService,
         webSocketManagerStore: WebSocketManagerStore) {
        self.assistantService = assistantService
        self.webSocketManagerStore = webSocketManagerStore
        setupClientStatusSubscriptions()
    }

    func cleanup() {
        AppLog.log.debug("AssistantsViewModel cleanup primaryAssistant to nil")
        self.assistantStatuses.removeAll()
        self.primaryAssistant = nil
    }

    var sortedAssistants: [AssistantStatus] {
        self.assistantStatuses.sorted { first, second in
            if first.assistant.metadata?.isPrimary == true {
                return true
            }
            if second.assistant.metadata?.isPrimary == true {
                return false
            }
            return first.isOnline && !second.isOnline
        }
    }

    private func setupClientStatusSubscriptions() {
        // Subscribe to WebSocket status updates
        webSocketManagerStore.$manager
            .compactMap { $0 }
            .flatMap { manager -> AnyPublisher<[ClientStatus], Never> in
                manager.$clientStatuses
                    .receive(on: DispatchQueue.main)
                    .eraseToAnyPublisher()
            }
            .sink { [weak self] clientStatuses in
                guard let self = self else { return }
                Task {
                    AppLog.log.debug("clientStatuses updated, updateAssistantStatuses")
                    await self.updateAssistantStatuses(assistants: self.assistants, clientStatuses: clientStatuses)
                }

            }
            .store(in: &cancellables)

        // Subscribe to assistants list updates
        assistantService.$assistants
            .sink { [weak self] assistants in
                guard let self = self else { return }
                Task {
                    if !assistants.isEmpty {
                        AppLog.log.debug("assistantService.$assistants changes, assistants size: \(assistants.count)")
                        await self.updateAssistants(with: assistants)
                    }
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
        AppLog.log.debug("updateAssistantStatuses")
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
                assistant: assistant,
                clientStatus: clientStatus
            )
        }
        let sortedStatuses = updatedStatuses.sorted { $0.isOnline && !$1.isOnline }
        assistantStatuses = sortedStatuses
        updatePrimaryAssistant()
    }

    private func updateAssistants(with assistants: [Assistant]) async {
        AppLog.log.debug("updateAssistants")
        self.assistants = assistants
        let clientStatuses = webSocketManagerStore.manager?.clientStatuses ?? []
        await updateAssistantStatuses(assistants: self.assistants, clientStatuses: clientStatuses)
    }

    func fetchAssistants(tag: String? = nil) async {
        AppLog.log.debug("fetchAssistants for: \(tag ?? "")")
        isLoading = true
        error = nil

        do {
            _ = try await assistantService.listAssistants()
        } catch {
            self.error = error
            AppLog.log.error("Error fetching assistants: \(error.localizedDescription)")
        }

        isLoading = false
    }

    func refreshAssistants() {
        AppLog.log.debug("refreshAssistants")
        Task {
            await fetchAssistants(tag: "refreshAssistants")
        }
    }

    func getClientStatus(for assistant: AssistantStatus) -> ClientStatus? {
        webSocketManagerStore.manager?.clientStatuses.first { $0.clientId == assistant.clientStatus?.clientId }
    }

    // MARK: - Assistant Management

    func deleteAssistant(_ assistant: AssistantStatus) async {
        do {
            try await assistantService.deleteAssistant(id: assistant.id)
            await fetchAssistants(tag: "deleteAssistant")
        } catch {
            self.error = error
            AppLog.log.error("Error deleting assistant: \(error.localizedDescription)")
        }
    }

    func createPrimaryAssistant() async {
        AppLog.log.debug("createPrimaryAssistant")
        do {
            _ = try await assistantService.createAssistant(name: nil, isPrimary: true)
            await fetchAssistants(tag: "createPrimaryAssistant")
        } catch {
            self.error = error
            AppLog.log.error("Error creating assistant: \(error.localizedDescription)")
        }
    }

    func createAssistant(name: String) async {
        do {
            _ = try await assistantService.createAssistant(name: name, isPrimary: false)
            await fetchAssistants(tag: "createAssistant")
        } catch {
            self.error = error
            AppLog.log.error("Error creating assistant: \(error.localizedDescription)")
        }
    }

    func getAssistantStatus(id: String) -> AssistantStatus? {
        return assistantStatuses.first { $0.id == id }
    }

    func updateAssistant(id: String, name: String) async -> AssistantStatus? {
        do {
            let updatedAssistant = try await assistantService.updateAssistant(id: id, name: name, metadata: nil)
            await fetchAssistants(tag: "updateAssistant")

            guard let assistant = updatedAssistant else {
                return nil
            }
            return getAssistantStatus(id: assistant.id)
        } catch {
            self.error = error
            AppLog.log.error("Error creating assistant: \(error.localizedDescription)")
        }
        return nil
    }

    func setPrimaryAssistant(id: String) async -> AssistantStatus? {
        do {
            let updatedAssistant = try await assistantService.updateAssistant(id: id, name: nil, metadata: AssistantMetadataUpdate(isPrimary: true))
            await fetchAssistants(tag: "setPrimaryAssistant")

            guard let assistant = updatedAssistant else {
                return nil
            }
            return getAssistantStatus(id: assistant.id)
        } catch {
            self.error = error
            AppLog.log.error("Error creating assistant: \(error.localizedDescription)")
        }
        return nil
    }

    private func updatePrimaryAssistant() {
        if let currentPrimaryId = primaryAssistant?.id,
           let updatedPrimary = assistantStatuses.first(where: { $0.id == currentPrimaryId && $0.assistant.metadata?.isPrimary == true }) {
            primaryAssistant = updatedPrimary
        } else {
            primaryAssistant = assistantStatuses.first(where: { $0.assistant.metadata?.isPrimary == true })
        }
    }
}
