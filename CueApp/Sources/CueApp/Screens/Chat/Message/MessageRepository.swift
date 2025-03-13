import Foundation
import Combine
import Dependencies
import CueCommon

enum MessageRepositoryError: Error {
    case saveFailed(underlying: Error)
    case fetchFailed(underlying: Error)
    case invalidConversationId
    case streamCreationFailed
    case messageNotFound
}

typealias MessageResult<T> = Result<T, MessageRepositoryError>

private enum MessageRepositoryKey: DependencyKey {
    static let liveValue: MessageRepositoryProtocol & Cleanable = MessageRepository(database: AppDatabase.shared)
    static var testValue: MessageRepository {
        MessageRepository(database: AppDatabase.empty())
    }
}

extension DependencyValues {
    var messageRepository: any MessageRepositoryProtocol & Cleanable {
        get { self[MessageRepositoryKey.self] }
        set { self[MessageRepositoryKey.self] = newValue }
    }
}

protocol MessageRepositoryProtocol: Sendable {
    func saveMessage(messageModel: MessageModel, enableRemote: Bool) async -> MessageResult<MessageModel>
    func listMessages(conversationId: String, skip: Int, limit: Int, enableRemote: Bool) async -> MessageResult<[MessageModel]>
    func getMessage(id: String) async -> MessageResult<MessageModel?>
    func fetchCachedMessages(forConversation conversationId: String, skip: Int, limit: Int) async -> MessageResult<[MessageModel]>
    func makeMessageStream(forConversation conversationId: String) async -> AsyncStream<MessageModel>
    func deleteCachedMessage(id: String) async
    func deleteAllCachedMessages(forConversation conversationId: String) async
    func deleteAllCachedMessages() async
}

actor MessageRepository: MessageRepositoryProtocol, Cleanable {
    @Dependency(\.messageService) private var messageService
    private let database: AppDatabase
    private let streamManager: MessageStreamManager

    init(database: AppDatabase, streamManager: MessageStreamManager = MessageStreamManager()) {
        self.streamManager = streamManager
        self.database = database
    }

    func saveMessage(messageModel: MessageModel, enableRemote: Bool) async -> MessageResult<MessageModel> {
        do {
            let finalMessage: MessageModel
            if enableRemote {
                finalMessage = try await messageService.saveMessage(messageModel)
                try await database.saveMessage(finalMessage)
            } else {
                finalMessage = messageModel
                try await database.saveMessage(messageModel)
            }
            await streamManager.emit(messageModel)
            return .success(messageModel)
        } catch {
            return .failure(.saveFailed(underlying: error))
        }
    }

    func listMessages(conversationId: String, skip: Int, limit: Int, enableRemote: Bool) async -> MessageResult<[MessageModel]> {
        do {
            if enableRemote {
                var messages = try await messageService.listMessages(
                    conversationId: conversationId,
                    skip: skip,
                    limit: limit
                )
                try await database.saveMessages(messages)
                messages.sort { $0.createdAt < $1.createdAt }
                return .success(messages)
            }
            var messages = try await database.fetchMessages(forConversation: conversationId, limit: limit, offset: skip)
            messages.sort { $0.createdAt < $1.createdAt }
            return .success(messages)
        } catch {
            return .failure(.fetchFailed(underlying: error))
        }
    }

    func fetchCachedMessages(forConversation conversationId: String, skip: Int = 0, limit: Int = 50) async -> MessageResult<[MessageModel]> {
        do {
            var messages = try await database.fetchMessages(forConversation: conversationId, limit: limit, offset: skip)
            messages.sort { $0.createdAt < $1.createdAt }
            return .success(messages)
        } catch {
            return .failure(.fetchFailed(underlying: error))
        }
    }

    func getMessage(id: String) async -> MessageResult<MessageModel?> {
        do {
            let message = try await messageService.getMessage(id: id)
            return .success(message)
        } catch {
            return .failure(.fetchFailed(underlying: error))
        }
    }

    func makeMessageStream(forConversation conversationId: String) async -> AsyncStream<MessageModel> {
        await streamManager.createStream(for: conversationId)
    }

    func deleteAllCachedMessages() async {
        try? await database.deleteAllMessages()
    }

    func deleteCachedMessage(id: String) async {
        try? await database.deleteMessage(id: id)
    }

    func deleteAllCachedMessages(forConversation conversationId: String) async {
        await streamManager.removePublisher(for: conversationId)
        try? await database.deleteConversation(id: conversationId)
    }

    func cleanup() async {
        await streamManager.clearAllStreams()
        try? await database.deleteAllMessages()
    }
}

actor MessageStreamManager {
    private var continuations: [String: AsyncStream<MessageModel>.Continuation] = [:]

    func createStream(for conversationId: String) -> AsyncStream<MessageModel> {
        if let existingContinuation = continuations[conversationId] {
            existingContinuation.finish()
            continuations.removeValue(forKey: conversationId)
        }

        return AsyncStream { continuation in
            storePublisher(conversationId: conversationId, continuation: continuation)

            continuation.onTermination = { [weak self] _ in
                Task {
                    await self?.removePublisher(for: conversationId)
                }
            }
        }
    }

    func emit(_ message: MessageModel) {
        let conversationId = message.conversationId
        continuations[conversationId]?.yield(message)
    }

    func clearAllStreams() {
        for (_, continuation) in continuations {
            continuation.finish()
        }
        continuations.removeAll()
    }

    private func storePublisher(conversationId: String, continuation: AsyncStream<MessageModel>.Continuation) {
        if continuations[conversationId] != nil {
            AppLog.log.warning("Publisher already exists for conversationId: \(conversationId)")
        }
        continuations[conversationId] = continuation
    }

    func removePublisher(for conversationId: String) {
        continuations[conversationId]?.finish()
        continuations.removeValue(forKey: conversationId)
    }
}
