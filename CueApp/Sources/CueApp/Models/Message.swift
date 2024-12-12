import Foundation

struct Message: Identifiable, Equatable {
    let id: String
    let assistantId: String?
    let conversationId: String?
    let content: String
    let isFromUser: Bool
    let timestamp: Date
    let type: MessageType

    enum MessageType {
        case user
        case assistant
    }

    init(id: String = UUID().uuidString, assistantId: String? = nil, conversationId: String? = nil, content: String, isFromUser: Bool, timestamp: Date = Date()) {
        self.id = id
        self.assistantId = assistantId
        self.conversationId = conversationId
        self.content = content
        self.isFromUser = isFromUser
        self.timestamp = timestamp
        self.type = isFromUser ? MessageType.user : MessageType.assistant
    }
}
