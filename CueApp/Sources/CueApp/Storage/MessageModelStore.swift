import Foundation
import GRDB
import Dependencies

// MARK: - Message Record for SQLite
struct MessageModelRecord: Codable, FetchableRecord, PersistableRecord {
    let id: String
    let conversationId: String
    let author: Data
    let content: Data
    let metadata: Data?
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

extension MessageModelStore: DependencyKey {
    public static let liveValue = try! MessageModelStore()
}

extension DependencyValues {
    var messageModelStore: MessageModelStore {
        get { self[MessageModelStore.self] }
        set { self[MessageModelStore.self] = newValue }
    }
}

// MARK: - MessageModel Store
actor MessageModelStore {
    private let dbPool: DatabasePool
    private let databaseFileName = "message_models.sqlite"

    init() throws {
        let fileManager = FileManager.default
        let folderURL = try fileManager.url(for: .applicationSupportDirectory,
                                          in: .userDomainMask,
                                          appropriateFor: nil,
                                          create: true)
        let dbPath = folderURL.appendingPathComponent(databaseFileName).path
        dbPool = try DatabasePool(path: dbPath)

        try dbPool.write { db in
            try MessageModelStore.setupTable(database: db)
        }
    }

    deinit {
        try? dbPool.close()
    }

    // MARK: - CRUD Operations
    func save(_ message: MessageModel) async throws {
        let record = try MessageModelRecord(message: message)
        try await dbPool.write { db in
            try record.save(db, onConflict: .replace)
        }
    }

    func saveList(_ messages: [MessageModel]) async throws {
        try dbPool.writeInTransaction { db in
            for message in messages {
                let record = try MessageModelRecord(message: message)
                try record.save(db)
            }
            return .commit
        }
    }

    func fetch(id: String) async throws -> MessageModel? {
        try await dbPool.read { db in
            if let record = try MessageModelRecord.fetchOne(db, key: id) {
                return try record.toMessageModel()
            }
            return nil
        }
    }

    func fetchMessages(forConversation conversationId: String, skip: Int = 0, limit: Int = 50) async throws -> [MessageModel] {
        try await dbPool.read { db in
            let records = try MessageModelRecord
                .filter(Column("conversationId") == conversationId)
                .order(Column("createdAt").desc)
                .limit(limit, offset: skip)
                .fetchAll(db)
            return try records.map { try $0.toMessageModel() }
        }
    }

    func delete(id: String) async throws {
        try await dbPool.write { db in
            _ = try MessageModelRecord.deleteOne(db, key: id)
        }
    }

    func deleteConversation(_ conversationId: String) async throws {
        try await dbPool.write { db in
            _ = try MessageModelRecord
                .filter(Column("conversationId") == conversationId)
                .deleteAll(db)
        }
    }

    func update(_ message: MessageModel) async throws {
        try await dbPool.write { db in
            let record = try MessageModelRecord(message: message)
            try record.update(db)
        }
    }

    func fetchConversations() async throws -> [String] {
        try await dbPool.read { db in
            let conversations = try String.fetchAll(db, sql: """
                SELECT DISTINCT conversationId
                FROM message_models
                WHERE conversationId IS NOT NULL
                ORDER BY MAX(createdAt) DESC
                """)
            return conversations
        }
    }

    func cleanup() async throws {
        try await dbPool.write { db in
            try db.drop(table: MessageModelRecord.databaseTableName)
            try MessageModelStore.setupTable(database: db)
        }
    }
}

extension MessageModelStore {
    static func setupTable(database: Database) throws {
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
