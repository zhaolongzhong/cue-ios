import Foundation
import Combine
import Dependencies

private enum MessageRepositoryKey: DependencyKey {
    static let liveValue: MessageRepository = MessageRepository()
}

extension DependencyValues {
    var messageRepository: MessageRepository {
        get { self[MessageRepositoryKey.self] }
        set { self[MessageRepositoryKey.self] = newValue }
    }
}

actor MessageRepository {
    @Dependency(\.assistantService) private var assistantService
    @Dependency(\.messageModelStore) private var messageModelStore
    private var continuations: [String: AsyncStream<MessageModel>.Continuation] = [:]

    init() {}

    func saveMessage(messageModel: MessageModel) async throws -> MessageModel {
        try await messageModelStore.save(messageModel)
        emit(messageModel)
        return messageModel
    }

    func listMessages(conversationId: String, skip: Int, limit: Int) async throws -> [MessageModel] {
        try await assistantService.listMessages(conversationId: conversationId, skip: skip, limit: limit)
    }

    func getMessage(id: String) async throws -> MessageModel? {
        try await assistantService.getMessage(id: id)
    }

    func fetchAllMessages(forConversation conversationId: String) async throws -> [MessageModel] {
        try await messageModelStore.fetchAllMessages(forConversation: conversationId)
    }

    func messageStream(forConversation conversationId: String) -> AsyncStream<MessageModel> {
        if continuations[conversationId] != nil {
            AppLog.log.warning("Publisher already exists for conversationId: \(conversationId)")
        }

        return AsyncStream { continuation in
            continuations[conversationId] = continuation

            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in
                    await self?.removePublisher(for: conversationId)
                }
            }
        }
    }

    private func emit(_ message: MessageModel) {
        let conversationId = message.conversationId
        continuations[conversationId]?.yield(message)
    }

    func removePublisher(for conversationId: String) async {
        continuations[conversationId]?.finish()
        continuations.removeValue(forKey: conversationId)
    }
}
