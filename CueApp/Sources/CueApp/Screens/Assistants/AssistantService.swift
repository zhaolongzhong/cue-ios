import os
import Foundation
import Dependencies
import CueCommon

enum AssistantError: LocalizedError {
    case networkError
    case invalidResponse
    case notFound
    case unknown

    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Network error occurred."
        case .invalidResponse:
            return "Invalid response from server."
        case .notFound:
            return "Assistant not found."
        case .unknown:
            return "An unknown error occurred."
        }
    }
}

extension AssistantService: DependencyKey {
    public static let liveValue = AssistantService()
}

extension DependencyValues {
    var assistantService: AssistantService {
        get { self[AssistantService.self] }
        set { self[AssistantService.self] = newValue }
    }
}

public final class AssistantService: Sendable {
    private let logger = Logger(subsystem: "AssistantService", category: "Assistant")

    public init() {}

    func createAssistant(name: String?, isPrimary: Bool = false) async throws -> Assistant {
        let assistantName = name ?? "Untitled"
        do {
            let assistant: Assistant = try await NetworkClient.shared.request(
                AssistantEndpoint.create(name: assistantName, isPrimary: isPrimary)
            )
            return assistant
        } catch {
            throw mapNetworkError(error)
        }
    }

    func getAssistant(id: String) async throws -> Assistant {
        do {
            let assistant: Assistant = try await NetworkClient.shared.request(
                AssistantEndpoint.get(id: id)
            )
            return assistant
        } catch NetworkError.httpError(let code, _) where code == 404 {
            throw AssistantError.notFound
        } catch {
            throw mapNetworkError(error)
        }
    }

    func listAssistants(skip: Int = 0, limit: Int = 5) async throws -> [Assistant] {
        do {
            let assistants: [Assistant] = try await NetworkClient.shared.request(
                AssistantEndpoint.list(skip: skip, limit: limit)
            )
            return assistants
        } catch {
            throw mapNetworkError(error)
        }
    }

    func deleteAssistant(id: String) async throws -> StatusResponse {
        do {
            let status: StatusResponse = try await NetworkClient.shared.request(
                AssistantEndpoint.delete(id: id)
            )
            return status
        } catch NetworkError.httpError(let code, _) where code == 404 {
            throw AssistantError.notFound
        } catch {
            throw mapNetworkError(error)
        }
    }

    func updateAssistant(id: String, name: String?, metadata: AssistantMetadataUpdate?) async throws -> Assistant {
        do {
            let assistant: Assistant = try await NetworkClient.shared.request(
                AssistantEndpoint.update(id: id, name: name, metadata: metadata)
            )
            return assistant
        } catch NetworkError.httpError(let code, _) where code == 404 {
            throw AssistantError.notFound
        } catch {
            throw mapNetworkError(error)
        }
    }

    func listAssistantConversations(id: String, isPrimary: Bool? = nil, skip: Int = 0, limit: Int = 10) async throws -> [ConversationModel] {
        do {
            let conversations: [ConversationModel] = try await NetworkClient.shared.request(
                AssistantEndpoint.listAssistantConversations(id: id, isPrimary: isPrimary, skip: skip, limit: limit)
            )
            return conversations
        } catch {
            throw mapNetworkError(error)
        }
    }

    func createPrimaryConversation(assistantId: String, name: String? = "default") async throws -> ConversationModel {
        do {
            let conversation: ConversationModel = try await NetworkClient.shared.request(
                AssistantEndpoint.createConversation(assistantId: assistantId, isPrimary: true)
            )
            return conversation
        } catch {
            throw mapNetworkError(error)
        }
    }

    private func mapNetworkError(_ error: Error) -> AssistantError {
        if let networkError = error as? NetworkError {
            switch networkError {
            case .httpError(let code, _):
                if code == 404 {
                    return .notFound
                }
                return .networkError
            default:
                return .networkError
            }
        }
        return .unknown
    }
}
