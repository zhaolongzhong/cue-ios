//
//  AppDatabase+Message.swift
//  CueApp
//

import Foundation
import GRDB
import os.log
import Dependencies
import CueCommon

// MARK: - Database Access: Message Operations

extension AppDatabase {
    /// Saves a message model. When the method returns, the
    /// message is present in the database with all properties updated.
    func saveMessage(_ message: MessageModel) async throws {
        let record = try MessageModelRecord(message: message)
        try await dbWriter.write { db in
            try record.save(db, onConflict: .replace)
        }
    }

    /// Saves multiple message models in a single transaction.
    func saveMessages(_ messages: [MessageModel]) async throws {
        try await dbWriter.write { db in
            for message in messages {
                let record = try MessageModelRecord(message: message)
                try record.save(db, onConflict: .replace)
            }
        }
    }

    /// Fetches a message by its ID.
    func fetchMessage(id: String) async throws -> MessageModel? {
        try await dbWriter.read { db in
            if let record = try MessageModelRecord.fetchOne(db, key: id) {
                return try record.toMessageModel()
            }
            return nil
        }
    }

    /// Fetches all messages, with optional limit and offset.
    func fetchAllMessages(limit: Int = 100, offset: Int = 0) async throws -> [MessageModel] {
        try await dbWriter.read { db in
            let records = try MessageModelRecord
                .order(Column("createdAt").desc)
                .limit(limit, offset: offset)
                .fetchAll(db)
            return try records.map { try $0.toMessageModel() }
        }
    }

    /// Fetches messages for a specific conversation.
    func fetchMessages(forConversation conversationId: String, limit: Int = 50, offset: Int = 0) async throws -> [MessageModel] {
        try await dbWriter.read { db in
            let records = try MessageModelRecord
                .filter(Column("conversationId") == conversationId)
                .order(Column("createdAt").desc)
                .limit(limit, offset: offset)
                .fetchAll(db)
            return try records.map { try $0.toMessageModel() }
        }
    }

    /// Deletes a message by its ID.
    func deleteMessage(id: String) async throws {
        try await dbWriter.write { db in
            _ = try MessageModelRecord.deleteOne(db, key: id)
        }
    }

    /// Deletes all messages for a specific conversation.
    func deleteMessages(forConversation conversationId: String) async throws {
        try await dbWriter.write { db in
            _ = try MessageModelRecord
                .filter(Column("conversationId") == conversationId)
                .deleteAll(db)
        }
    }

    /// Deletes all message
    func deleteAllMessages() async throws {
        _ = try await dbWriter.write { db in
            try MessageModelRecord.deleteAll(db)
        }
    }

    /// Updates an existing message.
    func updateMessage(_ message: MessageModel) async throws {
        let record = try MessageModelRecord(message: message)
        try await dbWriter.write { db in
            try record.update(db)
        }
    }

    /// Fetches all distinct conversation IDs.
    func fetchConversationIds() async throws -> [String] {
        try await dbWriter.read { db in
            try String.fetchAll(db, sql: """
                SELECT DISTINCT conversationId
                FROM \(MessageModelRecord.databaseTableName)
                WHERE conversationId IS NOT NULL AND conversationId != ''
                ORDER BY MAX(createdAt) DESC
                """)
        }
    }

    /// Counts messages in a specific conversation.
    func countMessages(inConversation conversationId: String) async throws -> Int {
        try await dbWriter.read { db in
            try MessageModelRecord
                .filter(Column("conversationId") == conversationId)
                .fetchCount(db)
        }
    }
}
