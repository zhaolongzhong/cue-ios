import Dependencies

private enum AssistantRepositoryKey: DependencyKey {
    static let liveValue: AssistantRepository = AssistantRepository()
}

extension DependencyValues {
    var assistantRepository: AssistantRepository {
        get { self[AssistantRepositoryKey.self] }
        set { self[AssistantRepositoryKey.self] = newValue }
    }
}

actor AssistantRepository {
    @Dependency(\.assistantService) private var assistantService
    @Dependency(\.messageModelStore) private var messageModelStore

    init() {}

    func createAssistant(name: String?, isPrimary: Bool) async throws -> Assistant {
        try await assistantService.createAssistant(name: name, isPrimary: isPrimary)
    }

    func getAssistant(id: String) async throws -> Assistant {
        try await assistantService.getAssistant(id: id)
    }

    func listAssistants(skip: Int = 0, limit: Int = 5) async throws -> [Assistant] {
        try await assistantService.listAssistants(skip: skip, limit: limit)
    }

    func deleteAssistant(id: String) async throws {
        try await assistantService.deleteAssistant(id: id)
    }

    func updateAssistant(id: String, name: String?, metadata: AssistantMetadataUpdate?) async throws -> Assistant {
        try await assistantService.updateAssistant(id: id, name: name, metadata: metadata)
    }

    func listAssistantConversations(id: String, isPrimary: Bool?, skip: Int, limit: Int) async throws -> [ConversationModel] {
        try await assistantService.listAssistantConversations(id: id, isPrimary: isPrimary, skip: skip, limit: limit)
    }

    func createPrimaryConversation(assistantId: String, name: String?) async throws -> ConversationModel {
        try await assistantService.createPrimaryConversation(assistantId: assistantId, name: name)
    }
}
