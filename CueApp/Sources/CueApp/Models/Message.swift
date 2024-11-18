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

    // Sample messages
    static func sampleMessages(assistantName: String) -> [Message] {
        [
            Message(assistantId: "default", conversationId: "default", content: "Hello! How can I help you today?", isFromUser: false),
            Message(assistantId: "default", conversationId: "default", content: "Hi \(assistantName)! Can you help me with a question?", isFromUser: true),
            Message(assistantId: "default", conversationId: "default", content: "Of course! I'd be happy to help. What's your question?", isFromUser: false)
        ]
    }
}
