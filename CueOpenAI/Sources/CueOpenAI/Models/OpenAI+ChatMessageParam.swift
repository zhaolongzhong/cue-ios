//
//  OpenAI+ChatMessageParam.swift
//  CueOpenAI
//

extension OpenAI {
    public enum ChatMessageParam: Codable, Sendable, Identifiable, Equatable {
        case userMessage(MessageParam)
        case assistantMessage(AssistantMessage, ChatCompletion? = nil)
        case toolMessage(ToolMessage)

        // Add coding keys if needed
        private enum CodingKeys: String, CodingKey {
            case role, content, toolCalls, toolCallId
        }

        // Implement encoding/decoding logic as needed
        public func encode(to encoder: Encoder) throws {
            _ = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .userMessage(let message):
                try message.encode(to: encoder)
            case .assistantMessage(let message, _):
                try message.encode(to: encoder)
            case .toolMessage(let message):
                try message.encode(to: encoder)
            }
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let role = try container.decode(String.self, forKey: .role)

            switch role {
            case "user":
                self = .userMessage(try MessageParam(from: decoder))
            case "assistant":
                self = .assistantMessage(try AssistantMessage(from: decoder), nil)
            case "tool":
                self = .toolMessage(try ToolMessage(from: decoder))
            default:
                throw DecodingError.dataCorruptedError(forKey: .role, in: container, debugDescription: "Unknown role type")
            }
        }
    }
}
extension OpenAI.ChatMessageParam {
    public var id: String {
        switch self {
        case .userMessage(let message):
            return "user_\(message)"
        case .assistantMessage(let message, _):
            return "assistant_\(message)"
        case .toolMessage(let message):
            return "tool_\(message)"
        }
    }

    public var role: String {
        switch self {
        case .userMessage:
            return "user"
        case .assistantMessage:
            return "assistant"
        case .toolMessage:
            return "tool"
        }
    }

    public var content: OpenAI.ContentValue {
        switch self {
        case .userMessage(let message):
            return message.content
        case .assistantMessage(let message, _):
            return .string(message.content ?? "")
        case .toolMessage(let message):
            return .string(message.content)
        }
    }

    public var contentBlocks: [OpenAI.ContentBlock] {
        switch self {
        case .userMessage(_):
            if case .string(let text) = content {
                return [.text(text)]
            } else if case .array(let contentBlocks) = content {
                return contentBlocks
            }
            return []
        case .assistantMessage(let message, _):
            return [.text(message.content ?? "")]
        case .toolMessage(let message):
            return [.text(message.content)]
        }
    }

    public var toolCalls: [ToolCall] {
        switch self {
        case .assistantMessage(let message, _):
            return message.toolCalls ?? []
        default:
            return []
        }
    }

    public var toolMessage: OpenAI.ToolMessage? {
        switch self {
        case .toolMessage(let message):
            return message
        default:
            return nil
        }
    }

    public var toolName: String? {
        toolCalls.map{ $0.function.name }.joined(separator: ", ")
    }

    public var toolArgs: String? {
        toolCalls.map { $0.function.prettyArguments }.joined(separator: ", ")
    }


    public var hasToolCall: Bool {
        switch self {
        case .assistantMessage(let param, _):
            return param.hasToolCall
        default:
            return false
        }
    }

    public var isToolMessage: Bool {
        switch self {
        case .toolMessage:
            return true
        default:
            return false
        }
    }

    public func toMessageParam(simple: Bool = false) -> OpenAI.ChatMessageParam {
        switch self {
        case .userMessage(let message):
            return .userMessage(message)
        case .assistantMessage(let message, _):
            if simple {
                return .assistantMessage(message.toMessageParam(), nil)
            }
            return .assistantMessage(message, nil)
        case .toolMessage(let message):
            if simple {
                return .assistantMessage(message.toAssistantMessage(), nil)
            }
            return .toolMessage(message)
        }
    }
}

extension OpenAI.ToolMessage {
    public func toAssistantMessage() -> OpenAI.AssistantMessage {
        return OpenAI.AssistantMessage(role: "assistant",  content : "toolCallId:\(toolCallId), Result:\(content)")
    }
}

extension OpenAI.AssistantMessage {
    public func toMessageParam(simple: Bool = true) -> OpenAI.AssistantMessage {
        // Create a combined content string
        var combinedContent = content ?? ""

        // If there are tool calls, convert them to a string representation
        if let tools = toolCalls, !tools.isEmpty {
            // Convert tool calls to a string representation
            let toolCallsString = tools.map { toolCall -> String in
                let functionName = toolCall.function.name
                let arguments = toolCall.function.arguments
                return "Function: \(functionName), Arguments: \(arguments)"
            }.joined(separator: "\n")

            // Add tool calls to the content
            if !combinedContent.isEmpty {
                combinedContent += "\n\nTool Calls:\n" + toolCallsString
            } else {
                combinedContent = "Tool Calls:\n" + toolCallsString
            }
        }

        // Return a new message with the combined content
        return OpenAI.AssistantMessage(
            role: role,
            content: combinedContent
        )
    }
}

