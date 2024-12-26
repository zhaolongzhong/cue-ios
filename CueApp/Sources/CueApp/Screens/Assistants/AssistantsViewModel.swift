import SwiftUI
import Combine
import Dependencies

@MainActor
final class AssistantsViewModel: ObservableObject {
    @Dependency(\.clientStatusService) public var clientStatusService
    @Dependency(\.webSocketService) public var webSocketService
    @Dependency(\.assistantRepository) private var assistantRepository

    @Published private(set) var assistants: [Assistant] = []
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
    }

    private func setupPrimaryAssistantSubscription() {
        $assistants
            .map { $0.first { $0.metadata?.isPrimary ?? false } }
            .assign(to: \.primaryAssistant, on: self)
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

    // MARK: - Public Methods
    func connect() async {
        await webSocketService.connect()
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

    // MARK: - Assistant Operations
    func fetchAssistants() async {
        isLoading = true
        defer { isLoading = false }

        switch await assistantRepository.listAssistants(skip: 0, limit: 5) {
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
            assistants.append(assistant)
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

    func setPrimaryAssistant(id: String) async {
        let previousPrimaryId = primaryAssistant?.id

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

    func updateMetadata(
        id: String,
        isPrimary: Bool? = nil,
        model: String? = nil,
        instruction: String? = nil,
        description: String? = nil,
        maxTurns: Int? = nil,
        context: JSONValue? = nil,
        system: JSONValue? = nil,
        tools: [String]? = nil
    ) async -> Assistant? {
        let metadata = AssistantMetadataUpdate(
            isPrimary: isPrimary,
            model: model,
            instruction: instruction,
            description: description,
            maxTurns: maxTurns,
            context: context,
            system: system,
            tools: tools
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

        await withTaskGroup(of: Void.self) { group in
            for assistantId in missingIds {
                group.addTask { [weak self] in
                    guard let self else { return }

                    switch await self.assistantRepository.getAssistant(id: assistantId) {
                    case .success(let assistant):
                        await MainActor.run {
                            self.assistants.append(assistant)
                            AppLog.log.debug("Added unmatched assistant: \(assistantId)")
                        }

                    case .failure(let error):
                        await MainActor.run {
                            handleError(error, context: "Fetching unmatched assistant failed")
                        }
                    }
                }
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
