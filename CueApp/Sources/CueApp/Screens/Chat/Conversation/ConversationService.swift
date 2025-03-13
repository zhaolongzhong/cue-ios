//
//  ConversationService.swift
//  CueApp
//

import Foundation
import Dependencies
import CueCommon
import os.log

enum ConversationError: LocalizedError {
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
            return "Conversation not found."
        case .unknown:
            return "An unknown error occurred."
        }
    }
}

extension ConversationService: DependencyKey {
    public static let liveValue = ConversationService()
}

extension DependencyValues {
    var conversationService: ConversationService {
        get { self[ConversationService.self] }
        set { self[ConversationService.self] = newValue }
    }
}

public final class ConversationService: Sendable {
    private let logger = Logger(subsystem: "ConversationService", category: "Conversation")

    public init() {}

    func createConversation(title: String? = nil, assistantId: String? = nil, isPrimary: Bool = false) async throws -> ConversationModel {
        let conversationTitle = title ?? "Default"
        do {
            let conversation: ConversationModel = try await NetworkClient.shared.request(
                ConversationEndpoint.create(title: conversationTitle, assistantId: assistantId, isPrimary: isPrimary)
            )
            return conversation
        } catch {
            throw mapNetworkError(error)
        }
    }

    func getConversation(id: String) async throws -> ConversationModel {
        do {
            let conversation: ConversationModel = try await NetworkClient.shared.request(
                ConversationEndpoint.get(id: id)
            )
            return conversation
        } catch NetworkError.httpError(let code, _) where code == 404 {
            throw ConversationError.notFound
        } catch {
            throw mapNetworkError(error)
        }
    }

    func listConversations(skip: Int = 0, limit: Int = 50) async throws -> [ConversationModel] {
        do {
            let conversations: [ConversationModel] = try await NetworkClient.shared.request(
                ConversationEndpoint.list(skip: skip, limit: limit)
            )
            return conversations
        } catch {
            throw mapNetworkError(error)
        }
    }

    func updateConversation(id: String, title: String? = nil, metadata: ConversationMetadataUpdate? = nil) async throws -> ConversationModel {
        do {
            var metadataDict: [String: Any]?
            if let metadata = metadata {
                if let metadataData = try? JSONEncoder().encode(metadata) {
                    metadataDict = try? JSONSerialization.jsonObject(with: metadataData, options: []) as? [String: Any]
                }
            }

            let conversation: ConversationModel = try await NetworkClient.shared.request(
                ConversationEndpoint.update(id: id, title: title, metadata: metadataDict)
            )
            return conversation
        } catch NetworkError.httpError(let code, _) where code == 404 {
            throw ConversationError.notFound
        } catch {
            throw mapNetworkError(error)
        }
    }

    func deleteConversation(id: String) async throws -> StatusResponse {
        do {
            let status: StatusResponse = try await NetworkClient.shared.request(
                ConversationEndpoint.delete(id: id)
            )
            return status
        } catch NetworkError.httpError(let code, _) where code == 404 {
            throw ConversationError.notFound
        } catch {
            throw mapNetworkError(error)
        }
    }

    func listConversationsByAssistantId(assistantId: String, isPrimary: Bool? = nil, skip: Int = 0, limit: Int = 50) async throws -> [ConversationModel] {
        do {
            let conversations: [ConversationModel] = try await NetworkClient.shared.request(
                ConversationEndpoint.listByAssistantId(assistantId: assistantId, isPrimary: isPrimary, skip: skip, limit: limit)
            )
            return conversations
        } catch {
            throw mapNetworkError(error)
        }
    }

    func createDefaultConversation(assistantId: String? = nil) async throws -> ConversationModel {
        if let assistantId = assistantId {
            do {
                // Try to find an existing primary conversation for this assistant
                let conversations = try await listConversationsByAssistantId(assistantId: assistantId, isPrimary: true)
                if let primaryConversation = conversations.first {
                    return primaryConversation
                }
            } catch {
                logger.error("Error while checking for existing primary conversations: \(error.localizedDescription)")
                // Continue to create a new one if there was an error
            }
        }

        // Create a new primary conversation
        return try await createConversation(title: "Default", assistantId: assistantId, isPrimary: true)
    }

    private func mapNetworkError(_ error: Error) -> ConversationError {
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
