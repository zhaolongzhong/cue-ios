import Foundation

public struct ConversationReadStatus: Identifiable, Codable {
    public let id: String
    public let userId: String
    public let conversationId: String
    public var lastReadAt: Date?
    public var lastReadMessageId: String?
    
    public init(
        id: String = UUID().uuidString,
        userId: String,
        conversationId: String,
        lastReadAt: Date? = nil,
        lastReadMessageId: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.conversationId = conversationId
        self.lastReadAt = lastReadAt
        self.lastReadMessageId = lastReadMessageId
    }
}