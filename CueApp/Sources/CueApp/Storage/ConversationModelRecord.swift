//
//  ConversationModelRecord.swift
//  CueApp
//

import Foundation
import Dependencies
import GRDB
import CueCommon

/// Database record for ConversationModel.
struct ConversationModelRecord: Codable, FetchableRecord, PersistableRecord {
    let id: String
    let title: String
    let assistantId: String?
    let metadata: Data?
    let createdAt: Date
    let updatedAt: Date

    static let databaseTableName = "conversation_models"

    // Define database columns
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let title = Column(CodingKeys.title)
        static let assistantId = Column(CodingKeys.assistantId)
        static let metadata = Column(CodingKeys.metadata)
        static let createdAt = Column(CodingKeys.createdAt)
        static let updatedAt = Column(CodingKeys.updatedAt)
    }

    // Convert ConversationModel to ConversationModelRecord
    init(conversation: ConversationModel) throws {
        self.id = conversation.id
        self.title = conversation.title
        self.assistantId = conversation.assistantId
        self.metadata = try conversation.metadata.map { try JSONEncoder().encode($0) }
        self.createdAt = conversation.createdAt
        self.updatedAt = conversation.updatedAt
    }

    // Convert ConversationModelRecord to ConversationModel
    func toConversationModel() throws -> ConversationModel {
        let decodedMetadata = try metadata.map { try JSONDecoder().decode(ConversationMetadata.self, from: $0) }

        return ConversationModel(
            id: id,
            title: title,
            createdAt: createdAt,
            updatedAt: updatedAt,
            assistantId: assistantId,
            metadata: decodedMetadata
        )
    }
}

// MARK: - Conversation Database Requests

/// Define some conversation requests used by the application.
extension DerivableRequest<ConversationModelRecord> {
    /// A request of conversations ordered by update date (newest first).
    func orderedByUpdateDate() -> Self {
        order(ConversationModelRecord.Columns.updatedAt.desc)
    }

    /// A request of conversations ordered by creation date (newest first).
    func orderedByCreationDate() -> Self {
        order(ConversationModelRecord.Columns.createdAt.desc)
    }

    /// A request of conversations with a specific assistant.
    func withAssistant(_ assistantId: String) -> Self {
        filter(ConversationModelRecord.Columns.assistantId == assistantId)
    }

    /// A request of conversations matching a search term in the title.
    func matching(searchTerm: String) -> Self {
        let pattern = "%\(searchTerm)%"
        return filter(ConversationModelRecord.Columns.title.like(pattern))
    }
}

// MARK: - ConversationModel Initializer Extension

extension ConversationModel {
    // Add a standard initializer to match the structure from the record
    init(id: String, title: String, createdAt: Date, updatedAt: Date, assistantId: String?, metadata: ConversationMetadata?) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.assistantId = assistantId
        self.metadata = metadata
    }
}
