import SwiftUI
import Combine

@MainActor
final class AssistantsViewModel: ObservableObject {
    @Published private(set) var assistants: [Assistant] = []
    @Published private(set) var clientStatuses: [String: ClientStatus] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var error: AssistantError?
    @Published private(set) var primaryAssistant: Assistant?
    @Published var assistantToDelete: Assistant?

    private let assistantService: AssistantService
    let webSocketManagerStore: WebSocketManagerStore
    private var cancellables = Set<AnyCancellable>()

    init(assistantService: AssistantService,
         webSocketManagerStore: WebSocketManagerStore) {
        self.assistantService = assistantService
        self.webSocketManagerStore = webSocketManagerStore
        setupClientStatusSubscriptions()
        setupPrimaryAssistantSubscription()
    }

    private func setupPrimaryAssistantSubscription() {
        $assistants
            .map { assistants in
                assistants.first(where: { $0.metadata?.isPrimary ?? false })
            }
            .assign(to: \.primaryAssistant, on: self)
            .store(in: &cancellables)
    }

    func cleanup() {
        AppLog.log.debug("AssistantsViewModel cleanup primaryAssistant to nil")
        self.assistants.removeAll()
        self.primaryAssistant = nil
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
                    AppLog.log.debug("clientStatuses updated, updating view model")
                    // Update the internal dictionary of statuses
                    let statusDict = [String: ClientStatus](
                        uniqueKeysWithValues: clientStatuses.compactMap { status in
                            guard let assistantId = status.assistantId else {
                                return nil
                            }
                            return (assistantId, status)
                        }
                    )
                    self.clientStatuses = statusDict
                    await self.findUnmatchedAssistants()

                    // Force a view update by reassigning assistants
                    self.assistants = self.assistants
                }
            }
            .store(in: &cancellables)
    }

    private func updateAssistants(with assistants: [Assistant]) async {
        AppLog.log.debug("updateAssistants")
        self.assistants = assistants
    }

    func fetchAssistants(tag: String? = nil) async {
        AppLog.log.debug("fetchAssistants for: \(tag ?? "")")
        isLoading = true
        error = nil

        do {
            let assistants = try await assistantService.listAssistants()
            self.assistants = assistants
        } catch let assistantError as AssistantError {
            self.error = assistantError
            AppLog.log.error("Error fetching assistants: \(assistantError.localizedDescription)")
        } catch {
            self.error = .unknown
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

    func getClientStatus(for assistant: Assistant) -> ClientStatus? {
        return webSocketManagerStore.getClientStatus(for: assistant.id)
    }

    // MARK: - Assistant Management

    func deleteAssistant(_ assistant: Assistant) async {
        AppLog.log.debug("Deleting assistant with ID: \(assistant.id)")
        do {
            try await assistantService.deleteAssistant(id: assistant.id)
            assistants.removeAll { $0.id == assistant.id }
            AppLog.log.debug("Deleted assistant with ID: \(assistant.id)")
        } catch let assistantError as AssistantError {
            self.error = assistantError
            AppLog.log.error("Error deleting assistant: \(assistantError.localizedDescription)")
        } catch {
            self.error = .unknown
            AppLog.log.error("Error deleting assistant: \(error.localizedDescription)")
        }
    }

    func createPrimaryAssistant() async {
        AppLog.log.debug("Creating primary assistant.")
        do {
            let newAssistant = try await assistantService.createAssistant(name: nil, isPrimary: true)
            assistants.append(newAssistant)
            AppLog.log.debug("Created primary assistant with ID: \(newAssistant.id)")
        } catch let assistantError as AssistantError {
            self.error = assistantError
            AppLog.log.error("Error creating primary assistant: \(assistantError.localizedDescription)")
        } catch {
            self.error = .unknown
            AppLog.log.error("Error creating primary assistant: \(error.localizedDescription)")
        }
        assistantToDelete = nil
    }

    func createAssistant(name: String) async -> Assistant? {
        AppLog.log.debug("Creating assistant with name: \(name)")
        do {
            let assistant = try await assistantService.createAssistant(name: name, isPrimary: false)
            assistants.append(assistant)
            AppLog.log.debug("Created assistant with ID: \(assistant.id)")
            return assistant
        } catch let assistantError as AssistantError {
            self.error = assistantError
            AppLog.log.error("Error creating assistant: \(assistantError.localizedDescription)")
        } catch {
            self.error = .unknown
            AppLog.log.error("Error creating assistant: \(error.localizedDescription)")
        }
        return nil
    }

    func updateAssistantName(id: String, name: String) async -> Assistant? {
        AppLog.log.debug("Updating name for assistant ID: \(id) to: \(name)")
        do {
            let updatedAssistant = try await assistantService.updateAssistant(id: id, name: name, metadata: nil)
            if let index = assistants.firstIndex(where: { $0.id == id }) {
                assistants[index] = updatedAssistant
            }
            AppLog.log.debug("Updated assistant name for ID: \(id)")
            return updatedAssistant
        } catch let assistantError as AssistantError {
            self.error = assistantError
            AppLog.log.error("Error updating assistant name: \(assistantError.localizedDescription)")
        } catch {
            self.error = .unknown
            AppLog.log.error("Error updating assistant name: \(error.localizedDescription)")
        }
        return nil
    }

    func updateMetadata(
        id: String,
        isPrimary: Bool? = nil,
        model: String? = nil,
        instruction: String? = nil,
        description: String? = nil,
        maxTurns: Int? = nil,
        context: JSONValue? = nil,
        tools: [String]? = nil
    ) async -> Assistant? {
        AppLog.log.debug("Updating metadata for assistant ID: \(id)")
        do {
            let metadata = AssistantMetadataUpdate(
                isPrimary: isPrimary,
                model: model,
                instruction: instruction,
                description: description,
                maxTurns: maxTurns,
                context: context,
                tools: tools
            )
            let updatedAssistant = try await assistantService.updateAssistant(id: id, name: nil, metadata: metadata)
            if let index = assistants.firstIndex(where: { $0.id == id }) {
                assistants[index] = updatedAssistant
            }
            AppLog.log.debug("Updated metadata for assistant ID: \(id)")
            return updatedAssistant
        } catch let assistantError as AssistantError {
            self.error = assistantError
            AppLog.log.error("Error updating assistant metadata: \(assistantError.localizedDescription)")
        } catch {
            self.error = .unknown
            AppLog.log.error("Error updating assistant metadata: \(error.localizedDescription)")
        }
        return nil
    }

    func setPrimaryAssistant(id: String) async {
        AppLog.log.debug("Setting primary assistant to ID: \(id)")
        do {
            let previousPrimaryId = primaryAssistant?.id
            let updatedAssistant = try await assistantService.updateAssistant(id: id, name: nil, metadata: AssistantMetadataUpdate(isPrimary: true, model: nil))
            if let index = assistants.firstIndex(where: { $0.id == id }) {
                assistants[index] = updatedAssistant
            }
            AppLog.log.debug("Set assistant ID \(id) as primary.")
            if let previousId = previousPrimaryId, previousId != id {
                let previousUpdatedAssistant = try await assistantService.getAssistant(id: previousId)
                if let index = assistants.firstIndex(where: { $0.id == previousId }) {
                    assistants[index] = previousUpdatedAssistant
                    AppLog.log.debug("Updated previous primary assistant ID \(previousId) to non-primary.")
                }
            }
        } catch let assistantError as AssistantError {
            self.error = assistantError
            AppLog.log.error("Error setting primary assistant: \(assistantError.localizedDescription)")
        } catch {
            self.error = .unknown
            AppLog.log.error("Error setting primary assistant: \(error.localizedDescription)")
        }
    }

    private func findUnmatchedAssistants() async {
        AppLog.log.debug("Finding unmatched assistants.")
        let existingAssistantIds = Set(assistants.map { $0.id })
        let statusAssistantIds = Set(clientStatuses.keys)
        let missingAssistantIds = statusAssistantIds.subtracting(existingAssistantIds)

        guard !missingAssistantIds.isEmpty else {
            AppLog.log.debug("No unmatched assistants found.")
            return
        }

        AppLog.log.debug("Found \(missingAssistantIds.count) unmatched assistants. Fetching...")

        await withTaskGroup(of: Void.self) { group in
            for assistantId in missingAssistantIds {
                group.addTask { [weak self] in
                    guard let self = self else { return }
                    do {
                        let fetchedAssistant = try await self.assistantService.getAssistant(id: assistantId)
                        await MainActor.run {
                            self.assistants.append(fetchedAssistant)
                            AppLog.log.debug("Fetched and added unmatched assistant ID: \(assistantId)")
                        }
                    } catch {
                        AppLog.log.error("Error fetching unmatched assistant \(assistantId): \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}
