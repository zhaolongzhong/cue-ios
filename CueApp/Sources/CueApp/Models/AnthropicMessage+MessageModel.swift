import Foundation
import CueCommon
import CueAnthropic

extension Anthropic.ChatMessageParam {
    public var id: String {
        // Create a unique identifier based on role and content
        "\(role)-\(content)".hash.description
    }
    
    func toMessageModel(conversationId: String) -> MessageModel {
        let author = Author(
            role: self.role,
            name: nil,
            metadata: nil
        )
        
        let content: MessageContent
        switch self {
        case .assistantMessage(let message):
            if let toolUses = message.toolUses {
                content = MessageContent(
                    type: "assistant_tool_use",
                    content: .array(toolUses.map { toolUse in
                        .object([
                            "type": .string("tool_use"),
                            "id": .string(toolUse.id),
                            "name": .string(toolUse.name),
                            "input": .object(toolUse.input)
                        ])
                    }),
                    toolCalls: nil
                )
            } else {
                content = MessageContent(
                    type: "assistant",
                    content: .string(message.content.first?.text ?? ""),
                    toolCalls: nil
                )
            }
            
        case .toolMessage(let message):
            content = MessageContent(
                type: "tool",
                content: .string(message.content.first?.text ?? ""),
                toolCalls: nil
            )
            
        case .userMessage(let message):
            content = MessageContent(
                type: "user",
                content: .string(message.content.first?.text ?? ""),
                toolCalls: nil
            )
        }
        
        let metadata = MessageMetadata(
            model: nil,
            usage: nil,
            payload: .object([
                "type": .string("anthropic"),
                "message": .object([
                    "role": .string(role),
                    "content": content.content
                ])
            ])
        )
        
        return MessageModel(
            id: id,
            conversationId: conversationId,
            author: author,
            content: content,
            metadata: metadata,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}