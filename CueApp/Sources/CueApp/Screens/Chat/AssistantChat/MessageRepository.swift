import Foundation
import Combine
import Dependencies

enum MessageRepositoryError: Error {
    case saveFailed(underlying: Error)
    case fetchFailed(underlying: Error)
    case invalidConversationId
    case streamCreationFailed
    case messageNotFound
}

typealias MessageResult<T> = Result<T, MessageRepositoryError>

private enum MessageRepositoryKey: DependencyKey {
    static let liveValue: MessageRepositoryProtocol & Cleanable = MessageRepository()
}

extension DependencyValues {
    var messageRepository: any MessageRepositoryProtocol & Cleanable {
        get { self[MessageRepositoryKey.self] }
        set { self[MessageRepositoryKey.self] = newValue }
    }
}

protocol MessageRepositoryProtocol: Sendable {
    func saveMessage(messageModel: MessageModel) async -> MessageResult<MessageModel>
    func listMessages(conversationId: String, skip: Int, limit: Int) async -> MessageResult<[MessageModel]>
    func getMessage(id: String) async -> MessageResult<MessageModel?>
    func fetchCachedMessages(forConversation conversationId: String, skip: Int, limit: Int) async -> MessageResult<[MessageModel]>
    func makeMessageStream(forConversation conversationId: String) async -> AsyncStream<MessageModel>
}

actor MessageRepository: MessageRepositoryProtocol, Cleanable {
    @Dependency(\.assistantService) private var assistantService
    @Dependency(\.messageModelStore) private var messageModelStore
    private let streamManager: MessageStreamManager

    init(streamManager: MessageStreamManager = MessageStreamManager()) {
        self.streamManager = streamManager
    }

    func saveMessage(messageModel: MessageModel) async -> MessageResult<MessageModel> {
        do {
            try await messageModelStore.save(messageModel)
            await streamManager.emit(messageModel)
            return .success(messageModel)
        } catch {
            return .failure(.saveFailed(underlying: error))
        }
    }

    func listMessages(conversationId: String, skip: Int, limit: Int) async -> MessageResult<[MessageModel]> {
        do {
            var messages = try await assistantService.listMessages(
                conversationId: conversationId,
                skip: skip,
                limit: limit
            )
            try await messageModelStore.saveList(messages)
            messages.sort { $0.createdAt < $1.createdAt }
            return .success(messages)
        } catch {
            return .failure(.fetchFailed(underlying: error))
        }
    }

    func fetchCachedMessages(forConversation conversationId: String, skip: Int = 0, limit: Int = 50) async -> MessageResult<[MessageModel]> {
        do {
            var messages = try await messageModelStore.fetchMessages(forConversation: conversationId, skip: skip, limit: limit)
            messages.sort { $0.createdAt < $1.createdAt }
            return .success(messages)
        } catch {
            return .failure(.fetchFailed(underlying: error))
        }
    }

    func getMessage(id: String) async -> MessageResult<MessageModel?> {
        do {
            let message = try await assistantService.getMessage(id: id)
            return .success(message)
        } catch {
            return .failure(.fetchFailed(underlying: error))
        }
    }

    func makeMessageStream(forConversation conversationId: String) async -> AsyncStream<MessageModel> {
        await streamManager.createStream(for: conversationId)
    }

    func cleanup() async {
        try? await messageModelStore.cleanup()
        await streamManager.clearAllStreams()
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

    private func removePublisher(for conversationId: String) {
        continuations[conversationId]?.finish()
        continuations.removeValue(forKey: conversationId)
    }
}
