import Foundation
import Combine
import os.log

enum AssistantError: LocalizedError {
    case networkError
    case invalidResponse
    case notFound
    case unknown

    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Network error occurred"
        case .invalidResponse:
            return "Invalid response from server"
        case .notFound:
            return "Assistant not found"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}

@MainActor
public class AssistantService: ObservableObject {
    public init() {}
    private let logger = Logger(subsystem: "AssistantService", category: "Assistant")
    private var primaryAssistantId: String?

    @Published private(set) var assistants: [Assistant] = []

    func cleanup() async {
        AppLog.log.debug("AssistantService cleanup")
        assistants = []
        primaryAssistantId = nil
    }

    func createAssistant(name: String, isPrimary: Bool) async throws -> Assistant {
        do {
            _ = AssistantCreate(name: name)
            let assistant: Assistant = try await NetworkClient.shared.request(
                AssistantEndpoint.create(name: name, isPrimary: isPrimary)
            )
            assistants.append(assistant)
            return assistant
        } catch {
            logger.error("Create assistant error: \(error.localizedDescription)")
            throw AssistantError.networkError
        }
    }

    func getAssistant(id: String) async throws -> Assistant {
        do {
            let assistant: Assistant = try await NetworkClient.shared.request(
                AssistantEndpoint.get(id: id)
            )
            if let existingIndex = assistants.firstIndex(where: { $0.id == assistant.id }) {
                assistants[existingIndex] = assistant
            } else {
                assistants.append(assistant)
            }
            return assistant
        } catch NetworkError.httpError(let code, _) where code == 404 {
            throw AssistantError.notFound
        } catch {
            logger.error("Get assistant error: \(error.localizedDescription)")
            throw AssistantError.networkError
        }
    }

    func listAssistants(skip: Int = 0, limit: Int = 5) async throws -> [Assistant] {
        AppLog.log.debug("AssistantService - listAssistants")
        do {
            let assistants: [Assistant] = try await NetworkClient.shared.request(
                AssistantEndpoint.list(skip: skip, limit: limit)
            )
            self.assistants = assistants
            return assistants
        } catch {
            logger.error("List assistants error: \(error.localizedDescription)")
            throw AssistantError.networkError
        }
    }

    func listAssistantConversations(id: String, isPrimary: Bool? = nil, skip: Int = 0, limit: Int = 10) async throws -> [ConversationModel] {
        AppLog.log.debug("AssistantService - listAssistantConversations")
        do {
            let conversations: [ConversationModel] = try await NetworkClient.shared.request(
                AssistantEndpoint.listAssistantConversations(id: id, isPrimary: isPrimary, skip: skip, limit: limit)
            )
            return conversations
        } catch {
            logger.error("List conversations by assistant id (\(id) error: \(error.localizedDescription)")
            throw AssistantError.networkError
        }
    }

    func listMessages(conversationId: String, skip: Int = 0, limit: Int = 20) async throws -> [MessageModel] {
        AppLog.log.debug("AssistantService - listMessages")
        do {
            let messages: [MessageModel] = try await NetworkClient.shared.request(
                AssistantEndpoint.listMessages(conversationId: conversationId, skip: skip, limit: limit)
            )
            return messages
        } catch {
            logger.error("List message by conversation id (\(conversationId) error: \(error.localizedDescription)")
            throw AssistantError.networkError
        }
    }

    func getMessage(id: String) async throws -> MessageModel? {
        do {
            let message: MessageModel? = try await NetworkClient.shared.request(
                AssistantEndpoint.getMessage(id: id)
            )
            return message
        } catch {
            logger.error("Get message by id (\(id) error: \(error.localizedDescription)")
            throw AssistantError.networkError
        }
    }

    func deleteAssistant(id: String) async throws {
        do {
            try await NetworkClient.shared.requestWithEmptyResponse(
                AssistantEndpoint.delete(id: id)
            )
            assistants.removeAll { $0.id == id }
            if primaryAssistantId == id {
                primaryAssistantId = nil
            }
        } catch NetworkError.httpError(let code, _) where code == 404 {
            throw AssistantError.notFound
        } catch {
            logger.error("Delete assistant error: \(error.localizedDescription)")
            throw AssistantError.networkError
        }
    }

    func createAssistant(name: String?, isPrimary: Bool = false) async throws -> String {
        do {
            let assistant: Assistant = try await NetworkClient.shared.request(
                AssistantEndpoint.create(name: name ?? "Untitled", isPrimary: isPrimary)
            )
            primaryAssistantId = assistant.id
            assistants.append(assistant)
            return assistant.id
        } catch {
            logger.error("Create default assistant error: \(error.localizedDescription)")
            throw AssistantError.networkError
        }
    }

    func createPrimaryConversation(assistantId: String, name: String? = "default") async throws -> ConversationModel {
        do {
            let conversation: ConversationModel = try await NetworkClient.shared.request(
                AssistantEndpoint.createConversation(assistantId: assistantId, isPriamary: true)
            )
            return conversation
        } catch {
            logger.error("Create default assistant error: \(error.localizedDescription)")
            throw AssistantError.networkError
        }
    }

    func getPrimaryAssistantId() -> String? {
        return primaryAssistantId
    }

    func updateAssistant(id: String, name: String?, metadata: AssistantMetadataUpdate?) async throws -> Assistant? {
        do {
            let assistant: Assistant = try await NetworkClient.shared.request(
                AssistantEndpoint.update(
                    id: id,
                    name: name,
                    metadata: metadata
                )
            )
            if let index = self.assistants.firstIndex(where: { $0.id == assistant.id }) {
                self.assistants[index] = assistant
            }
            return assistant
        } catch NetworkError.httpError(let code, _) where code == 404 {
            throw AssistantError.notFound
        } catch {
            logger.error("Update assistant error: \(error.localizedDescription)")
            throw AssistantError.networkError
        }
    }
}
