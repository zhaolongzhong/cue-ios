import SwiftUI
import Combine

@MainActor
public class AssistantsViewModel: ObservableObject {
    @Published private(set) var assistants: [Assistant] = []
    @Published private(set) var clientStatuses: [String: ClientStatus] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    @Published var primaryAssistant: Assistant?
    @Published var assistantToDelete: Assistant?

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

        // Subscribe to assistants list updates
        assistantService.$assistants
            .sink { [weak self] assistants in
                guard let self = self else { return }
                Task {
                    if !assistants.isEmpty {
                        AppLog.log.debug("assistantService.$assistants changes, assistants size: \(assistants.count)")
                        print("inx assistants: \(assistants)")
                        await self.updateAssistants(with: assistants)
                    }
                }

            }
            .store(in: &cancellables)
    }

    private func findUnmatchedAssistants() async {
        // Find missing assistants
        let existingAssistantIds = Set(self.assistants.map { $0.id })
        let statusAssistantIds = Set(self.clientStatuses.keys)
        let missingAssistantIds = statusAssistantIds.subtracting(existingAssistantIds)

        if !missingAssistantIds.isEmpty {
            AppLog.log.debug("Found \(missingAssistantIds.count) missing assistants, fetching...")

            // Fetch each missing assistant
            for assistantId in missingAssistantIds {
                do {
                    _ = try await assistantService.getAssistant(id: assistantId)
                } catch {
                    AppLog.log.error("Error fetching assistant \(assistantId): \(error.localizedDescription)")
                }
            }
        }
    }

    private func updateAssistants(with assistants: [Assistant]) async {
        AppLog.log.debug("updateAssistants")
        self.assistants = assistants
        updatePrimaryAssistant()
    }

    private func getAssistant(id: String) async {
        do {
            _ = try await assistantService.getAssistant(id: id)
        } catch {
            self.error = error
            AppLog.log.error("Error fetching assistants: \(error.localizedDescription)")
        }
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

    func getClientStatus(for assistant: Assistant) -> ClientStatus? {
        return webSocketManagerStore.getClientStatus(for: assistant.id)
    }

    // MARK: - Assistant Management

    func deleteAssistant(_ assistant: Assistant) async {
        do {
            try await assistantService.deleteAssistant(id: assistant.id)
            self.assistants = self.assistants.filter {$0.id != assistant.id}
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
        self.assistantToDelete = nil
    }

    func createAssistant(name: String) async -> Assistant? {
        do {
            let assistant = try await assistantService.createAssistant(name: name, isPrimary: false)
            return assistant
        } catch {
            self.error = error
            AppLog.log.error("Error creating assistant: \(error.localizedDescription)")
        }
        return nil
    }

    func updateAssistantName(id: String, name: String) async -> Assistant? {
        do {
            let assistant = try await assistantService.updateAssistant(id: id, name: name, metadata: nil)
            return assistant
        } catch {
            self.error = error
            AppLog.log.error("Error creating assistant: \(error.localizedDescription)")
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

            let updatedAssistant = try await assistantService.updateAssistant(
                id: id,
                name: nil,
                metadata: metadata
            )

            return updatedAssistant
        } catch {
            self.error = error
            AppLog.log.error("Error updating assistant metadata: \(error.localizedDescription)")
        }
        return nil
    }

    func setPrimaryAssistant(id: String) async {
        do {
            _ = try await assistantService.updateAssistant(id: id, name: nil, metadata: AssistantMetadataUpdate(isPrimary: true, model: nil))
            _ = await fetchAssistants(tag: "setPrimaryAssistant")
        } catch {
            self.error = error
            AppLog.log.error("Error creating assistant: \(error.localizedDescription)")
        }
    }

    private func updatePrimaryAssistant() {
        if let currentPrimaryId = primaryAssistant?.id,
           let updatedPrimary = self.assistants.first(where: { $0.id == currentPrimaryId && $0.metadata?.isPrimary == true }) {
            primaryAssistant = updatedPrimary
        } else {
            primaryAssistant = self.assistants.first(where: { $0.metadata?.isPrimary == true })
        }
    }
}
