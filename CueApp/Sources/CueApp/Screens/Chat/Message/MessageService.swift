//
//  MessageService.swift
//  CueApp
//

import os
import Foundation
import Dependencies
import CueCommon

extension MessageService: DependencyKey {
    public static let liveValue = MessageService()
}

extension DependencyValues {
    var messageService: MessageService {
        get { self[MessageService.self] }
        set { self[MessageService.self] = newValue }
    }
}

public final class MessageService: Sendable {
    private let logger = Logger(subsystem: "MessageService", category: "MessageService")

    public init() {}

    func listMessages(conversationId: String, skip: Int = 0, limit: Int = 20) async throws -> [MessageModel] {
        do {
            let messages: [MessageModel] = try await NetworkClient.shared.request(
                MessageEndpoint.list(conversationId: conversationId, skip: skip, limit: limit)
            )
            return messages
        } catch {
            throw mapNetworkError(error)
        }
    }

    func getMessage(id: String) async throws -> MessageModel? {
        do {
            let message: MessageModel? = try await NetworkClient.shared.request(
                MessageEndpoint.get(id: id)
            )
            return message
        } catch {
            throw mapNetworkError(error)
        }
    }

    func saveMessage(_ message: MessageModel) async throws -> MessageModel {
        do {
            let message: MessageModel = try await NetworkClient.shared.request(
                MessageEndpoint.create(message: message)
            )
            return message
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
