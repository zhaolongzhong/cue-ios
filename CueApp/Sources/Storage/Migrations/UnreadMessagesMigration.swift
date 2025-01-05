import Foundation

struct UnreadMessagesMigration: Migration {
    let version: Int = 1
    
    func migrate(storage: StorageProvider) async throws {
        // Add latest message tracking to conversations
        try await storage.execute("""
            ALTER TABLE conversations 
            ADD COLUMN latest_message_id TEXT REFERENCES messages(id),
            ADD COLUMN latest_message_at TIMESTAMP WITH TIME ZONE,
            ADD COLUMN latest_message_preview TEXT,
            ADD COLUMN latest_message_sender_id TEXT REFERENCES users(id)
        """)
        
        // Create read status tracking
        try await storage.execute("""
            CREATE TABLE conversation_read_status (
                id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL REFERENCES users(id),
                conversation_id TEXT NOT NULL REFERENCES conversations(id),
                last_read_at TIMESTAMP WITH TIME ZONE,
                last_read_message_id TEXT REFERENCES messages(id),
                UNIQUE(user_id, conversation_id)
            )
        """)
        
        // Create indexes
        try await storage.execute("""
            CREATE INDEX idx_conv_latest_msg ON conversations(latest_message_at);
            CREATE INDEX idx_read_status_user ON conversation_read_status(user_id);
            CREATE INDEX idx_read_status_conv ON conversation_read_status(conversation_id)
        """)
        
        // Initialize latest message data from existing messages
        try await storage.execute("""
            WITH latest_msgs AS (
                SELECT DISTINCT ON (conversation_id)
                    conversation_id,
                    id as msg_id,
                    created_at,
                    content->>'text' as preview,
                    sender_id
                FROM messages
                ORDER BY conversation_id, created_at DESC
            )
            UPDATE conversations c
            SET latest_message_id = lm.msg_id,
                latest_message_at = lm.created_at,
                latest_message_preview = left(lm.preview, 100),
                latest_message_sender_id = lm.sender_id
            FROM latest_msgs lm
            WHERE c.id = lm.conversation_id
        """)
    }
}