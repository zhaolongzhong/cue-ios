import Foundation
import GRDB

// MARK: - Message Record
struct MessageRecord: Codable, Identifiable, FetchableRecord, PersistableRecord {
    let id: String
    let assistantId: String
    let conversationId: String
    let content: String
    let isFromUser: Bool
    let timestamp: Date

    static let databaseTableName = "messages"

    // Convert Message domain model to MessageRecord
    init(message: Message) {
        self.id = message.id
        self.assistantId = message.assistantId ?? "default"
        self.conversationId = message.conversationId ?? "default"
        self.content = message.content
        self.isFromUser = message.isFromUser
        self.timestamp = message.timestamp
    }

    // Convert MessageRecord to Message domain model
    func toMessage() -> Message {
        Message(id: id, assistantId: assistantId, conversationId: conversationId, content: content, isFromUser: isFromUser, timestamp: timestamp)
    }
}

// MARK: - Database Manager
class MessageStore {
    private let dbPool: DatabasePool
    private let currentSchemaVersion = 2
    private let databaseFileName = "messages001.sqlite"

    init() throws {
        // Get the database file path in the app's documents directory

        let fileManager = FileManager.default
        let folderURL = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)

        let dbPath = folderURL.appendingPathComponent(databaseFileName).path

        // Initialize database pool
        dbPool = try DatabasePool(path: dbPath)

        try dbPool.write { db in
            try setupTable(database: db)
        }
    }

    // MARK: - CRUD Operations

    func save(_ data: Message) throws {
        try dbPool.write { db in
            let record = MessageRecord(message: data)
            try record.insert(db)
        }
    }

    func fetchAll() throws -> [Message] {
        try dbPool.read { db in
            let records = try MessageRecord
                .order(Column("timestamp").asc)
                .fetchAll(db)
            return records.map { $0.toMessage() }
        }
    }

    func delete(id: String) throws {
        _ = try dbPool.write { db in
            try MessageRecord.filter(id: id).deleteAll(db)
        }
    }

    func getByConversationId(forConversation conversationId: String) throws -> [Message] {
        try dbPool.read { db in
            let records = try MessageRecord
                .filter(Column("conversationId") == conversationId)
                .order(Column("timestamp").asc)
                .fetchAll(db)
            return records.map { $0.toMessage() }
        }
    }

    func deleteAllMessages() throws {
        _ = try dbPool.write { db in
            try MessageRecord.deleteAll(db)
        }
    }

    func deleteMessages(forConversation conversationId: String) throws {
        _ = try dbPool.write { db in
            try MessageRecord
                .filter(Column("conversationId") == conversationId)
                .deleteAll(db)
        }
    }

    func getConversations() throws -> [String] {
        try dbPool.read { db in
            let conversations = try String.fetchAll(db, sql: """
                SELECT DISTINCT conversationId
                FROM messages
                ORDER BY MAX(timestamp) DESC
                """)
            return conversations
        }
    }
}

extension MessageStore {
    func setupTable(database: Database) throws {
        try database.create(table: MessageRecord.databaseTableName, ifNotExists: true) { table in
            table.column("id", .text).primaryKey()
            table.column("assistantId", .text).notNull()
            table.column("conversationId", .text).notNull()
            table.column("content", .text).notNull()
            table.column("isFromUser", .boolean).notNull()
            table.column("timestamp", .datetime).notNull()
        }
    }
}
