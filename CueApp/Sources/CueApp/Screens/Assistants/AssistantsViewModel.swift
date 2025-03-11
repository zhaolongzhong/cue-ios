import SwiftUI
import Combine
import Dependencies
import CueCommon

@MainActor
public final class AssistantsViewModel: ObservableObject {
    @Dependency(\.clientStatusService) public var clientStatusService
    @Dependency(\.webSocketService) public var webSocketService
    @Dependency(\.assistantRepository) private var assistantRepository

    @Published private(set) var assistants: [Assistant] = []
    @Published private(set) var assistantsWithStatus: [AssistantWithStatus] = []
    @Published private(set) var clientStatuses: [String: ClientStatus] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var errorAlert: ErrorAlert?
    @Published private(set) var primaryAssistant: Assistant?
    @Published var assistantToDelete: Assistant?

    private var cancellables = Set<AnyCancellable>()

    init() {
        setupSubscriptions()
    }

    // MARK: - Setup
    private func setupSubscriptions() {
        setupClientStatusSubscription()
        setupPrimaryAssistantSubscription()
        setupAssistantsWithStatusSubscription()
    }

    private func setupPrimaryAssistantSubscription() {
        $assistants
            .map { $0.first { $0.metadata?.isPrimary ?? false } }
            .assign(to: \.primaryAssistant, on: self)
            .store(in: &cancellables)
    }
    
    private func setupAssistantsWithStatusSubscription() {
        // Combine assistants and client statuses into a consolidated model
        Publishers.CombineLatest($assistants, $clientStatuses)
            .map { assistants, statuses in
                assistants.map { assistant in
                    // Find the status for this assistant
                    let status = self.getClientStatus(for: assistant)
                    return AssistantWithStatus(assistant: assistant, status: status)
                }.sortedByStatusAndActivity()
            }
            .assign(to: \.assistantsWithStatus, on: self)
            .store(in: &cancellables)
    }

    private func setupClientStatusSubscription() {
        clientStatusService.$clientStatuses
            .receive(on: DispatchQueue.main)
            .sink { [weak self] statuses in
                guard let self else { return }
                Task {
                    await self.handleClientStatusUpdate(statuses)
                }
            }
            .store(in: &cancellables)
    }

    private func handleClientStatusUpdate(_ statuses: [String: ClientStatus]) async {
        let statusDict = [String: ClientStatus](uniqueKeysWithValues:
            statuses.values.compactMap { status in
                guard let assistantId = status.assistantId else { return nil }
                return (assistantId, status)
            }
        )

        self.clientStatuses = statusDict
        await findUnmatchedAssistants()
        self.objectWillChange.send()
    }

    func cleanup() {
        AppLog.log.debug("AssistantsViewModel cleanup")
        assistants.removeAll()
        primaryAssistant = nil
    }

    func refreshAssistants() {
        Task { await fetchAssistants() }
    }

    func getClientStatus(for assistant: Assistant) -> ClientStatus? {
        clientStatusService.getClientStatus(for: assistant.id)
    }
    
    // Helper method to get an AssistantWithStatus for a specific assistant
    func getAssistantWithStatus(for assistant: Assistant) -> AssistantWithStatus {
        let status = getClientStatus(for: assistant)
        return AssistantWithStatus(assistant: assistant, status: status)
    }

    func getAssistant(for assistantId: String) -> Assistant? {
        assistants.first { $0.id == assistantId }
    }

    // MARK: - Assistant Operations
    func fetchAssistants() async {
        isLoading = true
        defer { isLoading = false }

        switch await assistantRepository.listAssistants(skip: 0, limit: 20) {
        case .success(let fetchedAssistants):
            self.assistants = fetchedAssistants

        case .failure(.fetchFailed(let error)):
            handleError(error, context: "Fetching assistants failed")

        case .failure(let error):
            handleError(error, context: "Unknown error occurred")
        }
    }

    func deleteAssistant(_ assistant: Assistant) async {
        switch await assistantRepository.deleteAssistant(id: assistant.id) {
        case .success:
            assistants.removeAll { $0.id == assistant.id }
            AppLog.log.debug("Deleted assistant: \(assistant.id)")

        case .failure(let error):
            handleError(error, context: "Deleting assistant failed")
        }
    }

    func createPrimaryAssistant() async {
        switch await assistantRepository.createAssistant(name: nil, isPrimary: true) {
        case .success(let assistant):
            assistants.append(assistant)
            AppLog.log.debug("Created primary assistant: \(assistant.id)")

        case .failure(let error):
            handleError(error, context: "Creating primary assistant failed")
        }
        assistantToDelete = nil
    }

    func createAssistant(name: String) async -> Assistant? {
        switch await assistantRepository.createAssistant(name: name, isPrimary: false) {
        case .success(let assistant):
            assistants.insert(assistant, at: 0)
            AppLog.log.debug("Created assistant: \(assistant.id)")
            return assistant

        case .failure(let error):
            handleError(error, context: "Creating assistant failed")
            return nil
        }
    }

    func updateAssistantName(id: String, name: String) async -> Assistant? {
        switch await assistantRepository.updateAssistant(id: id, name: name, metadata: nil) {
        case .success(let assistant):
            updateLocalAssistant(assistant)
            return assistant

        case .failure(let error):
            handleError(error, context: "Updating assistant name failed")
            return nil
        }
    }

    func setPrimaryAssistant(id: String) {
        let previousPrimaryId = primaryAssistant?.id
        Task {
            switch await assistantRepository.updateAssistant(
                id: id,
                name: nil,
                metadata: AssistantMetadataUpdate(isPrimary: true, model: nil)
            ) {
            case .success(let assistant):
                updateLocalAssistant(assistant)

                if let previousId = previousPrimaryId, previousId != id {
                    await updatePreviousPrimaryAssistant(id: previousId)
                }

            case .failure(let error):
                handleError(error, context: "Setting primary assistant failed")
            }
        }
    }

    func updateMetadata(
        id: String,
        isPrimary: Bool? = nil,
        model: String? = nil,
        instruction: String? = nil,
        description: String? = nil,
        maxTurns: Int? = nil,
        context: JSONValue? = nil,
        tools: [String]? = nil,
        color: String? = nil
    ) async -> Assistant? {
        let metadata = AssistantMetadataUpdate(
            isPrimary: isPrimary,
            model: model,
            instruction: instruction,
            description: description,
            maxTurns: maxTurns,
            context: context,
            tools: tools,
            color: color
        )

        switch await assistantRepository.updateAssistant(id: id, name: nil, metadata: metadata) {
        case .success(let assistant):
            updateLocalAssistant(assistant)
            AppLog.log.debug("Updated metadata for assistant: \(id)")
            return assistant

        case .failure(.updateFailed(let error)):
            handleError(error, context: "Updating assistant metadata failed")
            return nil

        case .failure(.invalidAssistantId):
            handleError(AssistantRepositoryError.invalidAssistantId, context: "Invalid assistant ID")
            return nil

        case .failure(let error):
            handleError(error, context: "Unknown error occurred while updating metadata")
            return nil
        }
    }

    // MARK: - Private Helpers
    private func updateLocalAssistant(_ assistant: Assistant) {
        if let index = assistants.firstIndex(where: { $0.id == assistant.id }) {
            assistants[index] = assistant
        }
    }

    private func updatePreviousPrimaryAssistant(id: String) async {
        switch await assistantRepository.getAssistant(id: id) {
        case .success(let assistant):
            updateLocalAssistant(assistant)

        case .failure(let error):
            handleError(error, context: "Updating previous primary assistant failed")
        }
    }

    private func findUnmatchedAssistants() async {
        let existingIds = Set(assistants.map(\.id))
        let statusIds = Set(clientStatuses.keys)
        let missingIds = statusIds.subtracting(existingIds)

        guard !missingIds.isEmpty else { return }

        var newAssistants: [Assistant] = []
        var errors: [(AssistantRepositoryError, String)] = []

        await withTaskGroup(of: Result<Assistant, AssistantRepositoryError>.self) { group in
            for assistantId in missingIds {
                group.addTask { [weak self] in
                    guard let self else {
                        return .failure(.deallocated)
                    }

                    return await self.assistantRepository.getAssistant(id: assistantId)
                }
            }

            for await result in group {
                switch result {
                case .success(let assistant):
                    newAssistants.append(assistant)
                case .failure(let error):
                    errors.append((error, "Fetching unmatched assistant failed"))
                }
            }
        }

        await MainActor.run {
            let uniqueNewAssistants = newAssistants.filter { newAssistant in
                !self.assistants.contains { $0.id == newAssistant.id }
            }
            self.assistants.append(contentsOf: uniqueNewAssistants)

            for assistant in uniqueNewAssistants {
                AppLog.log.debug("Added unmatched assistant: \(assistant.id)")
            }

            for (error, context) in errors {
                handleError(error, context: context)
            }
        }
    }

    private func handleError(_ error: Error, context: String) {
        AppLog.log.error("\(context): \(error.localizedDescription)")
        errorAlert = ErrorAlert(
            title: "Error",
            message: "\(context): \(error.localizedDescription)"
        )
    }
}
