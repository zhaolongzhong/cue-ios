//
//  AppDatabase+Conversation.swift
//  CueApp
//

import os.log
import Foundation
import GRDB
import Dependencies
import CueCommon

// MARK: - Database Access: Conversation Operations

extension AppDatabase {
    /// Saves a conversation model. When the method returns, the
    /// conversation is present in the database with all properties updated.
    func saveConversation(_ conversation: ConversationModel) async throws {
        let record = try ConversationModelRecord(conversation: conversation)
        try await dbWriter.write { db in
            try record.save(db, onConflict: .replace)
        }
    }

    /// Fetches a conversation by its ID.
    func fetchConversation(id: String) async throws -> ConversationModel? {
        try await dbWriter.read { db in
            if let record = try ConversationModelRecord.fetchOne(db, key: id) {
                return try record.toConversationModel()
            }
            return nil
        }
    }

    /// Fetches all conversations, with optional limit and offset.
    func fetchAllConversations(limit: Int = 100, offset: Int = 0) async throws -> [ConversationModel] {
        try await dbWriter.read { db in
            let records = try ConversationModelRecord
                .order(Column("updatedAt").desc)
                .limit(limit, offset: offset)
                .fetchAll(db)
            return try records.map { try $0.toConversationModel() }
        }
    }

    /// Fetches all conversations for matching id prefix, with optional limit and offset.
    func fetchAllConversations(idPrefix: String?, assistantId: String? = nil, limit: Int = 100, offset: Int = 0) async throws -> [ConversationModel] {
         try await dbWriter.read { db in
             // Base query and parameters
             var sql = "SELECT * FROM \(ConversationModelRecord.databaseTableName) WHERE id LIKE ?"
             var arguments: [Any] = []

             // Add idPrefix filter if provided
             if let idPrefix = idPrefix {
                 arguments.append("\(idPrefix)%")
             }

             // Add assistantId filter if provided
             if let assistantId = assistantId {
                 sql += " AND assistantId = ?"
                 arguments.append(assistantId)
             }

             // Add ordering and pagination
             sql += " ORDER BY updatedAt DESC LIMIT ? OFFSET ?"
             arguments.append(limit)
             arguments.append(offset)

             // Explicitly convert [Any] to StatementArguments
             guard let statementArgs = StatementArguments(arguments) else {
                 return []
             }

             // Fetch records with the constructed query
             let records = try ConversationModelRecord.fetchAll(db, sql: sql, arguments: statementArgs)
             return try records.map { try $0.toConversationModel() }
         }
     }

    /// Deletes a conversation by its ID.
    func deleteConversation(id: String) async throws {
        try await dbWriter.write { db in
            _ = try ConversationModelRecord.deleteOne(db, key: id)

            // Also delete all messages belonging to this conversation
            _ = try MessageModelRecord
                .filter(Column("conversationId") == id)
                .deleteAll(db)
        }
    }

    /// Deletes all conversations
    func deleteAllConversations() async throws {
        _ = try await dbWriter.write { db in
            try ConversationModelRecord.deleteAll(db)
        }
    }

    /// Updates an existing conversation.
    func updateConversation(_ conversation: ConversationModel) async throws {
        let record = try ConversationModelRecord(conversation: conversation)
        try await dbWriter.write { db in
            try record.update(db)
        }
    }

    /// Fetches conversations matching a title search term.
    func searchConversations(matching term: String, limit: Int = 20) async throws -> [ConversationModel] {
        try await dbWriter.read { db in
            let pattern = "%\(term)%"
            let records = try ConversationModelRecord
                .filter(Column("title").like(pattern))
                .order(Column("updatedAt").desc)
                .limit(limit)
                .fetchAll(db)
            return try records.map { try $0.toConversationModel() }
        }
    }

    /// Fetches the primary conversation (where metadata.isPrimary is true).
    /// Optionally filter by assistantId and/or idPrefix.
    func fetchPrimaryConversation(assistantId: String? = nil, idPrefix: String? = nil) async throws -> ConversationModel? {
        try await dbWriter.read { db in
            // Build the query with optional filters
            var query = ConversationModelRecord.all()

            // Apply filters if provided
            if let assistantId = assistantId {
                query = query.filter(Column("assistantId") == assistantId)
            }

            if let idPrefix = idPrefix {
                query = query.filter(Column("id").like("\(idPrefix)%"))
            }

            // Order by update time (most recent first)
            query = query.order(Column("updatedAt").desc)

            // Fetch the filtered conversations
            let filteredConversations = try query.fetchAll(db)

            // Find the first one with isPrimary=true in its metadata
            for record in filteredConversations {
                let conversation = try record.toConversationModel()
                if let metadata = conversation.metadata, metadata.isPrimary {
                    return conversation
                }
            }

            return nil
        }
    }
}
