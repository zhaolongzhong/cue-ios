import Foundation
import GRDB

// MARK: - Message Record for SQLite
struct MessageModelRecord: Codable, FetchableRecord, PersistableRecord {
    let id: String
    let conversationId: String?
    let author: Data        // JSON blob for Author
    let content: Data       // JSON blob for MessageContent
    let metadata: Data?     // JSON blob for MessageMetadata
    let createdAt: Date
    let updatedAt: Date

    static let databaseTableName = "message_models"

    // Convert MessageModel to MessageModelRecord
    init(message: MessageModel) throws {
        self.id = message.id ?? UUID().uuidString
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

// MARK: - MessageModel Store
class MessageModelStore {
    private let dbPool: DatabasePool
    private let databaseFileName = "message_models.sqlite"

    init() throws {
        let fileManager = FileManager.default
        let folderURL = try fileManager.url(for: .documentDirectory,
                                          in: .userDomainMask,
                                          appropriateFor: nil,
                                          create: true)
        let dbPath = folderURL.appendingPathComponent(databaseFileName).path
        dbPool = try DatabasePool(path: dbPath)

        try dbPool.write { db in
            try setupTable(database: db)
        }
    }

    // MARK: - CRUD Operations
    func save(_ message: MessageModel) throws {
        try dbPool.write { db in
            let record = try MessageModelRecord(message: message)
            try record.save(db, onConflict: .replace)
        }
    }

    func fetch(id: String) throws -> MessageModel? {
        try dbPool.read { db in
            if let record = try MessageModelRecord.fetchOne(db, key: id) {
                return try record.toMessageModel()
            }
            return nil
        }
    }

    func fetchAllMessages(forConversation conversationId: String) throws -> [MessageModel] {
        try dbPool.read { db in
            let records = try MessageModelRecord
                .filter(Column("conversationId") == conversationId)
                .order(Column("createdAt").asc)
                .fetchAll(db)
            return try records.map { try $0.toMessageModel() }
        }
    }

    func delete(id: String) throws {
        try dbPool.write { db in
            _ = try MessageModelRecord.deleteOne(db, key: id)
        }
    }

    func deleteConversation(_ conversationId: String) throws {
        try dbPool.write { db in
            _ = try MessageModelRecord
                .filter(Column("conversationId") == conversationId)
                .deleteAll(db)
        }
    }

    func update(_ message: MessageModel) throws {
        guard message.id != nil else {
            throw NSError(domain: "MessageModelStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "Message ID is required for update"])
        }

        try dbPool.write { db in
            let record = try MessageModelRecord(message: message)
            try record.update(db)
        }
    }

    func fetchConversations() throws -> [String] {
        try dbPool.read { db in
            let conversations = try String.fetchAll(db, sql: """
                SELECT DISTINCT conversationId
                FROM message_models
                WHERE conversationId IS NOT NULL
                ORDER BY MAX(createdAt) DESC
                """)
            return conversations
        }
    }

    private func setupTable(database: Database) throws {
        try database.create(table: MessageModelRecord.databaseTableName, ifNotExists: true) { table in
            table.column("id", .text).primaryKey()
            table.column("conversationId", .text)
            table.column("author", .blob).notNull()
            table.column("content", .blob).notNull()
            table.column("metadata", .blob)
            table.column("createdAt", .datetime).notNull()
            table.column("updatedAt", .datetime).notNull()
        }
    }
}
