import Foundation
import CueCommon
import CueOpenAI
import CueAnthropic
import CueGemini

extension CueChatMessage {
    func toMessageModel(conversationId: String) -> MessageModel {
        let author = Author(
            role: self.role,
            name: nil,  // Could be added if needed
            metadata: nil  // Could be extended with provider-specific metadata
        )
        
        let content: MessageContent
        switch self {
        case .openAI(let msg):
            content = convertOpenAIContent(msg)
        case .anthropic(let msg):
            content = convertAnthropicContent(msg)
        case .gemini(let msg):
            content = convertGeminiContent(msg)
        case .cue(let msg):
            // Already in correct format
            content = msg.content
        }
        
        let metadata = MessageMetadata(
            model: getModelIdentifier(),
            usage: nil,  // Could be added if needed
            payload: getOriginalPayload()
        )
        
        return MessageModel(
            id: self.id,
            conversationId: conversationId,
            author: author,
            content: content,
            metadata: metadata,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    private func convertOpenAIContent(_ msg: OpenAI.ChatMessageParam) -> MessageContent {
        switch msg {
        case .assistantMessage(let message):
            if let toolCalls = message.toolCalls {
                return MessageContent(
                    type: "assistant_tool_call",
                    content: .string(message.content ?? ""),
                    toolCalls: toolCalls.map { call in
                        ToolCall(
                            id: call.id,
                            type: "function",
                            function: Function(
                                name: call.function.name,
                                arguments: call.function.arguments
                            )
                        )
                    }
                )
            } else {
                return MessageContent(
                    type: "assistant",
                    content: .string(message.content ?? ""),
                    toolCalls: nil
                )
            }
            
        case .toolMessage(let message):
            return MessageContent(
                type: "tool",
                content: .string(message.content),
                toolCalls: nil
            )
            
        default:
            return MessageContent(
                type: "text",
                content: .string(msg.content),
                toolCalls: nil
            )
        }
    }
    
    private func convertAnthropicContent(_ msg: Anthropic.ChatMessageParam) -> MessageContent {
        switch msg {
        case .assistantMessage(let message):
            if let toolUses = message.toolUses {
                return MessageContent(
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
                return MessageContent(
                    type: "assistant",
                    content: .string(message.content.first?.text ?? ""),
                    toolCalls: nil
                )
            }
            
        case .toolMessage(let message):
            return MessageContent(
                type: "tool",
                content: .string(message.content.first?.text ?? ""),
                toolCalls: nil
            )
            
        default:
            return MessageContent(
                type: "text",
                content: .string(msg.content),
                toolCalls: nil
            )
        }
    }
    
    private func convertGeminiContent(_ msg: Gemini.ChatMessageParam) -> MessageContent {
        switch msg {
        case .assistantMessage(let message):
            if let functionCalls = message.functionCalls {
                return MessageContent(
                    type: "assistant_tool_call",
                    content: .string(message.content),
                    toolCalls: functionCalls.map { call in
                        ToolCall(
                            id: UUID().uuidString,  // Gemini doesn't provide IDs
                            type: "function",
                            function: Function(
                                name: call.name,
                                arguments: call.args
                            )
                        )
                    }
                )
            } else {
                return MessageContent(
                    type: "assistant",
                    content: .string(message.content),
                    toolCalls: nil
                )
            }
            
        case .toolMessage(let message):
            if case .functionResponse(let response) = message.parts.first {
                return MessageContent(
                    type: "tool",
                    content: .string(response.response["content"]?.asString ?? ""),
                    toolCalls: nil
                )
            } else {
                return MessageContent(
                    type: "tool",
                    content: .string(msg.content),
                    toolCalls: nil
                )
            }
            
        default:
            return MessageContent(
                type: "text",
                content: .string(msg.content),
                toolCalls: nil
            )
        }
    }
    
    private func getModelIdentifier() -> String? {
        switch self {
        case .openAI: return "gpt-4"  // Could be made more specific
        case .anthropic: return "claude-3"  // Could be made more specific
        case .gemini: return "gemini-pro"
        case .cue(let msg): return msg.metadata?.model
        }
    }
    
    private func getOriginalPayload() -> JSONValue? {
        switch self {
        case .openAI(let msg):
            return .object([
                "type": .string("openai"),
                "message": .object(["content": .string(msg.content)])
            ])
        case .anthropic(let msg):
            return .object([
                "type": .string("anthropic"),
                "message": .object(["content": .string(msg.content)])
            ])
        case .gemini(let msg):
            return .object([
                "type": .string("gemini"),
                "message": .object(["content": .string(msg.content)])
            ])
        case .cue(let msg):
            return msg.metadata?.payload
        }
    }
}

// Helper initializer for MessageModel
extension MessageModel {
    init(
        id: String,
        conversationId: String,
        author: Author,
        content: MessageContent,
        metadata: MessageMetadata?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.conversationId = conversationId
        self.author = author
        self.content = content
        self.metadata = metadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // Convert MessageModel back to CueChatMessage
    public func toCueChatMessage() -> CueChatMessage {
        // First check if this was originally from a specific provider
        if let providerType = metadata?.payload?["type"]?.asString {
            switch providerType {
            case "openai":
                return convertToOpenAI()
            case "anthropic":
                return convertToAnthropic()
            case "gemini":
                return convertToGemini()
            default:
                break
            }
        }
        
        // If no specific provider or unknown, return as Cue message
        return .cue(self)
    }
    
    private func convertToOpenAI() -> CueChatMessage {
        let baseMessage: OpenAI.ChatMessageParam
        
        switch content.type {
        case "assistant_tool_call":
            let toolCalls = content.toolCalls?.map { toolCall in
                OpenAI.ChatCompletionToolCall(
                    id: toolCall.id,
                    type: toolCall.type,
                    function: OpenAI.ChatCompletionFunction(
                        name: toolCall.function.name,
                        arguments: toolCall.function.arguments
                    )
                )
            }
            
            baseMessage = .assistantMessage(
                .init(
                    content: content.text,
                    toolCalls: toolCalls
                )
            )
            
        case "tool":
            baseMessage = .toolMessage(
                .init(
                    toolCallId: content.toolCalls?.first?.id ?? "",
                    content: content.text
                )
            )
            
        case "assistant":
            baseMessage = .assistantMessage(
                .init(content: content.text)
            )
            
        default:
            if author.role == "user" {
                baseMessage = .userMessage(content: content.text)
            } else {
                baseMessage = .assistantMessage(.init(content: content.text))
            }
        }
        
        return .openAI(baseMessage)
    }
    
    private func convertToAnthropic() -> CueChatMessage {
        let baseMessage: Anthropic.ChatMessageParam
        
        switch content.type {
        case "assistant_tool_use":
            if case .array(let toolUses) = content.content {
                let anthropicToolUses: [Anthropic.ToolUseBlock] = toolUses.compactMap { toolUse in
                    guard case .object(let dict) = toolUse,
                          let id = dict["id"]?.asString,
                          let name = dict["name"]?.asString,
                          case .object(let input) = dict["input"] else {
                        return nil
                    }
                    
                    return Anthropic.ToolUseBlock(
                        type: "tool_use",
                        id: id,
                        input: input,
                        name: name
                    )
                }
                
                baseMessage = .assistantMessage(
                    .init(
                        content: [.init(type: "text", text: content.text)],
                        toolUses: anthropicToolUses
                    )
                )
            } else {
                baseMessage = .assistantMessage(
                    .init(content: [.init(type: "text", text: content.text)])
                )
            }
            
        case "tool":
            baseMessage = .toolMessage(
                .init(
                    toolName: content.toolName ?? "",
                    content: [
                        .init(type: "text", text: content.text)
                    ]
                )
            )
            
        default:
            if author.role == "user" {
                baseMessage = .userMessage(content: content.text)
            } else {
                baseMessage = .assistantMessage(
                    .init(content: [.init(type: "text", text: content.text)])
                )
            }
        }
        
        return .anthropic(baseMessage)
    }
    
    private func convertToGemini() -> CueChatMessage {
        let baseMessage: Gemini.ChatMessageParam
        
        switch content.type {
        case "assistant_tool_call":
            let functionCalls = content.toolCalls?.map { toolCall in
                Gemini.FunctionCall(
                    name: toolCall.function.name,
                    args: toolCall.function.arguments
                )
            }
            
            baseMessage = .assistantMessage(
                .init(
                    content: content.text,
                    functionCalls: functionCalls
                )
            )
            
        case "tool":
            baseMessage = .toolMessage(
                .init(
                    parts: [
                        .functionResponse(
                            .init(
                                name: content.toolName ?? "",
                                response: ["content": .string(content.text)]
                            )
                        )
                    ]
                )
            )
            
        default:
            if author.role == "user" {
                baseMessage = .userMessage(content: content.text)
            } else {
                baseMessage = .assistantMessage(.init(content: content.text))
            }
        }
        
        return .gemini(baseMessage)
    }
}

// Helper extensions for content access
extension MessageContent {
    var text: String {
        switch content {
        case .string(let str):
            return str
        case .array(let arr):
            return arr.map { $0.description }.joined(separator: "\n")
        case .object(let obj):
            return obj.description
        }
    }
    
    var toolName: String? {
        if let firstTool = toolCalls?.first {
            return firstTool.function.name
        }
        return nil
    }
    
    var toolArgs: String? {
        if let firstTool = toolCalls?.first {
            return firstTool.function.arguments
        }
        return nil
    }
}