import Foundation
import Dependencies

enum AssistantRepositoryError: Error {
    case createFailed(underlying: Error)
    case fetchFailed(underlying: Error)
    case updateFailed(underlying: Error)
    case deleteFailed(underlying: Error)
    case invalidAssistantId
    case invalidConversationId
    case conversationCreationFailed(underlying: Error)
    case deallocated
}

struct CustomError: Error, LocalizedError {
    let message: String

    var errorDescription: String? {
        return message
    }
}

typealias AssistantResult<T> = Result<T, AssistantRepositoryError>

private enum AssistantRepositoryKey: DependencyKey {
    static let liveValue: AssistantRepositoryProtocol & Cleanable = AssistantRepository()
}

extension DependencyValues {
    var assistantRepository: AssistantRepositoryProtocol & Cleanable {
        get { self[AssistantRepositoryKey.self] }
        set { self[AssistantRepositoryKey.self] = newValue }
    }
}

protocol AssistantRepositoryProtocol: Sendable {
    func createAssistant(name: String?, isPrimary: Bool) async -> AssistantResult<Assistant>
    func getAssistant(id: String) async -> AssistantResult<Assistant>
    func listAssistants(skip: Int, limit: Int) async -> AssistantResult<[Assistant]>
    func deleteAssistant(id: String) async -> AssistantResult<Void>
    func updateAssistant(id: String, name: String?, metadata: AssistantMetadataUpdate?) async -> AssistantResult<Assistant>
    func listAssistantConversations(id: String, isPrimary: Bool?, skip: Int, limit: Int) async -> AssistantResult<[ConversationModel]>
    func createPrimaryConversation(assistantId: String, name: String?) async -> AssistantResult<ConversationModel>
}

actor AssistantRepository: AssistantRepositoryProtocol, Cleanable {
    @Dependency(\.assistantService) private var assistantService

    init() {}

    func cleanup() async {
        // Stub
    }

    func createAssistant(name: String?, isPrimary: Bool) async -> AssistantResult<Assistant> {
        do {
            let assistant = try await assistantService.createAssistant(name: name, isPrimary: isPrimary)
            return .success(assistant)
        } catch {
            return .failure(.createFailed(underlying: error))
        }
    }

    func getAssistant(id: String) async -> AssistantResult<Assistant> {
        guard !id.isEmpty else {
            return .failure(.invalidAssistantId)
        }

        do {
            let assistant = try await assistantService.getAssistant(id: id)
            return .success(assistant)
        } catch {
            return .failure(.fetchFailed(underlying: error))
        }
    }

    func listAssistants(skip: Int = 0, limit: Int = 5) async -> AssistantResult<[Assistant]> {
        do {
            let assistants = try await assistantService.listAssistants(skip: skip, limit: limit)
            return .success(assistants)
        } catch {
            return .failure(.fetchFailed(underlying: error))
        }
    }

    func deleteAssistant(id: String) async -> AssistantResult<Void> {
        guard !id.isEmpty else {
            return .failure(.invalidAssistantId)
        }

        do {
            let status = try await assistantService.deleteAssistant(id: id)
            if status.success {
                return .success(())
            } else {
                let customError = CustomError(message: "Delete failed due to unknown reasons.")
                return .failure(.deleteFailed(underlying: customError))
            }
        } catch {
            return .failure(.deleteFailed(underlying: error))
        }
    }

    func updateAssistant(id: String, name: String?, metadata: AssistantMetadataUpdate?) async -> AssistantResult<Assistant> {
        guard !id.isEmpty else {
            return .failure(.invalidAssistantId)
        }

        do {
            let updated = try await assistantService.updateAssistant(id: id, name: name, metadata: metadata)
            return .success(updated)
        } catch {
            return .failure(.updateFailed(underlying: error))
        }
    }

    func listAssistantConversations(id: String, isPrimary: Bool?, skip: Int, limit: Int) async -> AssistantResult<[ConversationModel]> {
        guard !id.isEmpty else {
            return .failure(.invalidAssistantId)
        }

        do {
            let conversations = try await assistantService.listAssistantConversations(
                id: id,
                isPrimary: isPrimary,
                skip: skip,
                limit: limit
            )
            return .success(conversations)
        } catch {
            return .failure(.fetchFailed(underlying: error))
        }
    }

    func createPrimaryConversation(assistantId: String, name: String?) async -> AssistantResult<ConversationModel> {
        guard !assistantId.isEmpty else {
            return .failure(.invalidAssistantId)
        }

        do {
            let conversation = try await assistantService.createPrimaryConversation(
                assistantId: assistantId,
                name: name
            )
            return .success(conversation)
        } catch {
            return .failure(.conversationCreationFailed(underlying: error))
        }
    }
}
