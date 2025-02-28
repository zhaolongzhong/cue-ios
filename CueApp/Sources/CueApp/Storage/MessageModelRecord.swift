//
//  MessageModelRecord.swift
//  CueApp
//

import Foundation
import Dependencies
import GRDB
import CueCommon

/// Database record for MessageModel.
struct MessageModelRecord: Codable, FetchableRecord, PersistableRecord {
    let id: String
    let conversationId: String
    let author: Data
    let content: Data
    let metadata: Data?
    let createdAt: Date
    let updatedAt: Date

    static let databaseTableName = "message_models"

    // Define database columns
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let conversationId = Column(CodingKeys.conversationId)
        static let author = Column(CodingKeys.author)
        static let content = Column(CodingKeys.content)
        static let metadata = Column(CodingKeys.metadata)
        static let createdAt = Column(CodingKeys.createdAt)
        static let updatedAt = Column(CodingKeys.updatedAt)
    }

    // Convert MessageModel to MessageModelRecord
    init(message: MessageModel) throws {
        self.id = message.id
        self.conversationId = message.conversationId
        self.author = try JSONEncoder().encode(message.author)
        self.content = try JSONEncoder().encode(message.content)
        self.metadata = try message.metadata.map { try JSONEncoder().encode($0) }
        self.createdAt = message.createdAt
        self.updatedAt = message.updatedAt
    }

    // Convert MessageModelRecord to MessageModel
    func toMessageModel() throws -> MessageModel {
        let decodedAuthor = try JSONDecoder().decode(Author.self, from: author)
        let decodedContent = try JSONDecoder().decode(MessageContent.self, from: content)
        let decodedMetadata = try metadata.map { try JSONDecoder().decode(MessageMetadata.self, from: $0) }

        return MessageModel(
            id: id,
            conversationId: conversationId,
            author: decodedAuthor,
            content: decodedContent,
            metadata: decodedMetadata,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

// MARK: - Message Database Requests

/// Define some message requests used by the application.
extension DerivableRequest<MessageModelRecord> {
    /// A request of messages ordered by creation date (newest first).
    func orderedByCreationDate() -> Self {
        order(MessageModelRecord.Columns.createdAt.desc)
    }

    /// A request of messages for a specific conversation.
    func inConversation(_ conversationId: String) -> Self {
        filter(MessageModelRecord.Columns.conversationId == conversationId)
    }
}
