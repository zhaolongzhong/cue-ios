//
//  ConversationRepository.swift
//  CueApp
//

import Foundation
import Dependencies
import CueCommon

enum ConversationRepositoryError: Error {
    case saveFailed(underlying: Error)
    case fetchFailed(underlying: Error)
    case createFailed(underlying: Error)
    case deleteFailed(underlying: Error)
    case updateFailed(underlying: Error)
    case conversationNotFound
}

typealias ConversationResult<T> = Result<T, ConversationRepositoryError>

private enum ConversationRepositoryKey: DependencyKey {
    static let liveValue: ConversationRepositoryProtocol & Cleanable = ConversationRepository(database: AppDatabase.shared)
}

extension DependencyValues {
    var conversationRepository: any ConversationRepositoryProtocol & Cleanable {
        get { self[ConversationRepositoryKey.self] }
        set { self[ConversationRepositoryKey.self] = newValue }
    }
}

protocol ConversationRepositoryProtocol: Sendable {
    func createConversation(title: String, assistantId: String?, isPrimary: Bool, provider: Provider?) async throws -> ConversationModel
    func save(_ conversationModel: ConversationModel) async throws
    func delete(id: String) async throws
    func update(_ conversationModel: ConversationModel) async throws
    func listConversations(limit: Int, offset: Int) async throws -> [ConversationModel]
    func getConversation(id: String) async throws -> ConversationModel?
    func fetchConversationsByProvider(provider: Provider, limit: Int, offset: Int) async throws -> [ConversationModel]
}

actor ConversationRepository: ConversationRepositoryProtocol, Cleanable {
    @Dependency(\.assistantService) private var assistantService
    @Dependency(\.messageRepository) private var messageRepository

    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func createConversation(title: String, assistantId: String?, isPrimary: Bool = false, provider: Provider?) async throws -> ConversationModel {
        let conversationId = "\(ConversationModel.getConversationIdPrefix(for: provider))_\(UUID().uuidString.lowercased().prefix(8))"
        let newConversation = ConversationModel(
            id: conversationId,
            title: title,
            createdAt: Date(),
            updatedAt: Date(),
            assistantId: nil,
            metadata: ConversationMetadata(isPrimary: false)
        )

        try await database.saveConversation(newConversation)
        return newConversation
    }

    func save(_ conversation: ConversationModel) async throws {
        try await database.saveConversation(conversation)
    }

    func getConversation(id: String) async throws -> ConversationModel? {
        return try await database.fetchConversation(id: id)
    }

    func getAllConversations(limit: Int = 100, offset: Int = 0) async throws -> [ConversationModel] {
        return try await database.fetchAllConversations(limit: limit, offset: offset)
    }

    func getAllConversations(idPrefix: String, assistantId: String? = nil, limit: Int = 100, offset: Int = 0) async throws -> [ConversationModel] {
        return try await database.fetchAllConversations(idPrefix: idPrefix, assistantId: assistantId, limit: limit, offset: offset)
    }
    func listConversations(limit: Int = 100, offset: Int = 0) async throws -> [ConversationModel] {
        return try await database.fetchAllConversations()
    }

    func fetchCachedConversations(limit: Int = 100, offset: Int = 0) async -> ConversationResult<[ConversationModel]> {
        do {
            let conversations = try await database.fetchAllConversations(limit: limit, offset: offset)
            return .success(conversations)
        } catch {
            return .failure(.fetchFailed(underlying: error))
        }
    }

    func delete(id: String) async throws {
        await messageRepository.deleteAllCachedMessages(forConversation: id)
        try await database.deleteConversation(id: id)
    }

    func update(_ conversation: ConversationModel) async throws {
        try await database.updateConversation(conversation)
    }

    func search(matching term: String, limit: Int = 20) async throws -> [ConversationModel] {
        return try await database.searchConversations(matching: term, limit: limit)
    }

    func getPrimaryConversation(assistantId: String? = nil, idPrefix: String? = nil) async throws -> ConversationModel? {
        return try await database.fetchPrimaryConversation(assistantId: assistantId, idPrefix: idPrefix)
    }

    func setAsPrimaryConversation(_ conversationId: String) async throws {
        // First, remove primary status from any existing primary conversation
        if let existing = try await getPrimaryConversation() {
            var updatedConversation = existing
            // Create new metadata with isPrimary set to false
            let newMetadata = ConversationMetadata(isPrimary: false, capabilities: existing.metadata?.capabilities)
            // Use KeyPath assignment if your struct allows it, or create a new instance
            updatedConversation = ConversationModel(
                id: existing.id,
                title: existing.title,
                createdAt: existing.createdAt,
                updatedAt: Date(),
                assistantId: existing.assistantId,
                metadata: newMetadata
            )
            try await database.updateConversation(updatedConversation)
        }

        // Now set the new conversation as primary
        if var conversation = try await database.fetchConversation(id: conversationId) {
            // Create new metadata with isPrimary set to true
            let newMetadata = ConversationMetadata(isPrimary: true, capabilities: conversation.metadata?.capabilities)
            // Use KeyPath assignment if your struct allows it, or create a new instance
            conversation = ConversationModel(
                id: conversation.id,
                title: conversation.title,
                createdAt: conversation.createdAt,
                updatedAt: Date(),
                assistantId: conversation.assistantId,
                metadata: newMetadata
            )
            try await database.updateConversation(conversation)
        }
    }

    func fetchConversationsByProvider(provider: Provider, limit: Int, offset: Int) async throws -> [ConversationModel] {
        let prefix = ConversationModel.getConversationIdPrefix(for: provider)
        let conversations = try await database.fetchAllConversations(idPrefix: prefix, limit: limit, offset: offset)
        return conversations
    }

    func cleanup() async {
        try? await database.deleteAllConversations()
    }
}

extension ConversationModel {
    static func getConversationIdPrefix(for provider: Provider?) -> String {
        guard let provider = provider else {
            return "conv"
        }
        return "\(provider.displayName.lowercased().prefix(3))_conv"
    }

    var provider: Provider? {
        let prefix = self.id.prefix(3).lowercased()
        return Provider.AllCases().first(where: { $0.displayName.lowercased().contains(prefix)})
    }
}
