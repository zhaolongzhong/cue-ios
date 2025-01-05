import Foundation

public struct ConversationStatus {
    public let conversation: Conversation
    public let readStatus: ConversationReadStatus?
}

public protocol ConversationRepository {
    func getConversationsStatus(userId: String) async throws -> [ConversationStatus]
    func getConversationStatus(conversationId: String, userId: String) async throws -> ConversationStatus
    func markAsRead(conversationId: String, userId: String, messageId: String?) async throws
    func updateLatestMessage(
        conversationId: String,
        messageId: String,
        timestamp: Date,
        preview: String?,
        senderId: String
    ) async throws
}

public class DefaultConversationRepository: ConversationRepository {
    private let storage: StorageProvider
    
    public init(storage: StorageProvider) {
        self.storage = storage
    }
    
    public func getConversationsStatus(userId: String) async throws -> [ConversationStatus] {
        let conversations = try await storage.fetch(
            Conversation.self,
            query: """
            SELECT * FROM conversations 
            WHERE ? = ANY(participants)
            ORDER BY latest_message_at DESC NULLS LAST
            """,
            [userId]
        )
        
        let readStatuses = try await storage.fetch(
            ConversationReadStatus.self,
            query: """
            SELECT * FROM conversation_read_status 
            WHERE user_id = ?
            """,
            [userId]
        )
        
        let readStatusMap = Dictionary(
            uniqueKeysWithValues: readStatuses.map { ($0.conversationId, $0) }
        )
        
        return conversations.map { conversation in
            ConversationStatus(
                conversation: conversation,
                readStatus: readStatusMap[conversation.id]
            )
        }
    }
    
    public func getConversationStatus(
        conversationId: String,
        userId: String
    ) async throws -> ConversationStatus {
        guard let conversation = try await storage.fetchOne(
            Conversation.self,
            query: "SELECT * FROM conversations WHERE id = ?",
            [conversationId]
        ) else {
            throw ConversationError.notFound
        }
        
        let readStatus = try await storage.fetchOne(
            ConversationReadStatus.self,
            query: """
            SELECT * FROM conversation_read_status 
            WHERE conversation_id = ? AND user_id = ?
            """,
            [conversationId, userId]
        )
        
        return ConversationStatus(
            conversation: conversation,
            readStatus: readStatus
        )
    }
    
    public func markAsRead(
        conversationId: String,
        userId: String,
        messageId: String? = nil
    ) async throws {
        let now = Date()
        
        try await storage.execute("""
            INSERT INTO conversation_read_status 
            (id, user_id, conversation_id, last_read_at, last_read_message_id)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT (user_id, conversation_id) 
            DO UPDATE SET 
                last_read_at = EXCLUDED.last_read_at,
                last_read_message_id = EXCLUDED.last_read_message_id
            """,
            [
                UUID().uuidString,
                userId,
                conversationId,
                now,
                messageId
            ]
        )
    }
    
    public func updateLatestMessage(
        conversationId: String,
        messageId: String,
        timestamp: Date,
        preview: String?,
        senderId: String
    ) async throws {
        try await storage.execute("""
            UPDATE conversations 
            SET latest_message_id = ?,
                latest_message_at = ?,
                latest_message_preview = ?,
                latest_message_sender_id = ?
            WHERE id = ?
            """,
            [
                messageId,
                timestamp,
                preview,
                senderId,
                conversationId
            ]
        )
    }
}

public enum ConversationError: Error {
    case notFound
    case invalidMessage
}