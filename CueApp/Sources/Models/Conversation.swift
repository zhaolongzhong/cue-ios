import Foundation

public struct Conversation: Identifiable, Codable {
    public let id: String
    public var title: String
    public var participants: [String] // User IDs
    public var latestMessageId: String?
    public var latestMessageAt: Date?
    public var latestMessagePreview: String?
    public var latestMessageSenderId: String?
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        participants: [String],
        latestMessageId: String? = nil,
        latestMessageAt: Date? = nil,
        latestMessagePreview: String? = nil,
        latestMessageSenderId: String? = nil
    ) {
        self.id = id
        self.title = title
        self.participants = participants
        self.latestMessageId = latestMessageId
        self.latestMessageAt = latestMessageAt
        self.latestMessagePreview = latestMessagePreview
        self.latestMessageSenderId = latestMessageSenderId
    }
}