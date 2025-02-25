import Foundation
import CueCommon
import CueOpenAI
import CueAnthropic
import CueGemini

public enum CueChatMessage: Encodable, Sendable, Identifiable {
    case local(OpenAI.ChatMessageParam, stableId: String? = nil, streamingState: StreamingState? = nil)
    case openAI(OpenAI.ChatMessageParam)
    case anthropic(Anthropic.ChatMessageParam, stableId: String? = nil, streamingState: StreamingState? = nil)
    case gemini(Gemini.ChatMessageParam)
    case cue(MessageModel)

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .local(let msg, _, _):
            try container.encode(msg)
        case .openAI(let msg):
            try container.encode(msg)
        case .anthropic(let msg, _, _):
            try container.encode(msg)
        case .gemini(let msg):
            try container.encode(msg)
        case .cue(let msg):
            try container.encode(msg)
        }
    }

    public var id: String {
        switch self {
        case .local(let msg, let stableId, _):
            return stableId ?? msg.id
        case .openAI(let msg):
            return msg.id
        case .anthropic(let msg, let stableId, _):
            return stableId ?? msg.id
        case .gemini(let msg):
            return String(describing: msg)
        case .cue(let msg):
            return msg.id
        }
    }

    static func streamingMessage(
        id: String,
        content: String,
        toolCalls: [ToolCall] = [],
        streamingState: StreamingState? = nil
    ) -> Self {
        .local(
            .assistantMessage(
                OpenAI.AssistantMessage(
                    role: Role.assistant.rawValue,
                    content: content,
                    toolCalls: toolCalls
                )
            ),
            stableId: id,
            streamingState: streamingState
        )
    }

    static func streamingAnthropicMessage(
        id: String,
        streamingState: StreamingState
    ) -> Self {
        .anthropic(
            .assistantMessage(
                Anthropic.MessageParam(
                    role: Role.assistant.rawValue,
                    content: streamingState.contentBlocks
                )
            ),
            stableId: id,
            streamingState: streamingState
        )
    }

    var role: String {
        switch self {
        case .local(let msg, _, _): return msg.role
        case .openAI(let msg): return msg.role
        case .anthropic(let msg, _, _): return msg.role
        case .gemini(let msg): return msg.role
        case .cue(let msg): return msg.author.role
        }
    }

    var content: OpenAI.ContentValue {
        switch self {
        case .local(let msg, _, _): return msg.content
        case .openAI(let msg): return msg.content
        case .anthropic(let msg, _, _): return .string(msg.content)
        case .gemini(let msg): return .string(msg.content)
        case .cue(let msg): return .string(msg.content.text)
        }
    }

    var isUser: Bool {
        switch self {
        case .local(let msg, _, _): return msg.role == "user"
        case .openAI(let msg): return msg.role == "user"
        case .anthropic(let msg, _, _):
            if case .userMessage = msg {
                return true
            }
            return false
        case .gemini(let msg):
            if case .userMessage = msg {
                return true
            }
            return false
        case .cue(let msg): return msg.isUser
        }
    }

    var isTool: Bool {
        switch self {
        case .local(let msg, _, _):
            if case .assistantMessage(let message) = msg {
                return message.hasToolCall
            }
        case .openAI(let msg):
            if case .assistantMessage(let message) = msg {
                return message.hasToolCall
            }
        case .anthropic(let msg, _, _):
            if case .assistantMessage(let message) = msg {
                return message.hasToolUse
            }
        case .gemini(let msg):
            if case .assistantMessage = msg {
                return msg.hasFunctionCalls
            }
        case .cue(let msg): return msg.isTool
        }
        return false
    }

    var isToolMessage: Bool {
        switch self {
        case .local(let msg, _, _):
            if case .toolMessage = msg {
                return true
            }
        case .openAI(let msg):
            if case .toolMessage = msg {
                return true
            }
        case .anthropic(let msg, _, _):
            if case .toolMessage = msg {
                return true
            }
        case .gemini(let msg):
            if case .toolMessage = msg {
                return true
            }
        case .cue(let msg): return msg.isToolMessage
        }
        return false
    }

    var toolResultContent: String {
        let content: String = {
            switch self {
            case .local(let msg, _, _):
                if case .toolMessage(let toolMessage) = msg {
                    return toolMessage.content
                }
                return msg.content.contentAsString
            case .openAI(let msg):
                if case .toolMessage(let toolMessage) = msg {
                    return toolMessage.content
                }
                return msg.content.contentAsString
            case .anthropic(let msg, _, _):
                if case .toolMessage(let toolMessage) = msg {
                    if let content = toolMessage.content.first?.content.first {
                        switch content {
                        case .text(let text):
                            return text.text
                        default:
                            return ""
                        }
                    }
                }
                return msg.content
            case .gemini(let msg):
                if case .toolMessage(let toolMessage) = msg {
                    if case .functionResponse(let response) = toolMessage.parts.first {
                        if case .string(let content) = response.response["content"] {
                            return content
                        }
                    }
                }
                return msg.content
            case .cue(let msg):
                return msg.content.text
            }
        }()

        return JSONFormatter.prettyToolResult(content)
    }

    var toolName: String? {
        switch self {
        case .local(let msg, _, _):
            return msg.toolName
        case .openAI(let msg):
            return msg.toolName
        case .anthropic(let msg, _, _):
            return msg.toolName
        case .gemini(let msg):
            return msg.toolName
        case .cue(let msg):
            return msg.content.toolName
        }
    }

    var toolArgs: String? {
        switch self {
        case .local(let msg, _, _):
            return msg.toolArgs
        case .openAI(let msg):
            return msg.toolArgs
        case .anthropic(let msg, _, _):
            return msg.toolArgs
        case .gemini(let msg):
            return msg.toolArgs
        case .cue(let msg):
            return msg.content.toolArgs
        }
    }

    var anthropic: Anthropic.ChatMessageParam {
        switch self {
        case .anthropic(let param, _, _):
            return param
        default:
            fatalError("Not implemented: Conversion to Anthropic.ChatMessageParam")
        }
    }

    var isAnthropic: Bool {
        switch self {
        case .anthropic:
            return true
        default:
            return false
        }
    }

    var stableId: String {
        switch self {
        case .anthropic(_, let stableId, _):
            return stableId ?? ""
        default:
            fatalError("Not implemented: stableId")
        }
    }
}

extension CueChatMessage: Equatable {
    public static func == (lhs: CueChatMessage, rhs: CueChatMessage) -> Bool {
        // Basic identity check
        guard lhs.id == rhs.id, lhs.content == rhs.content else {
            return false
        }

        // If both are .local, compare the streamingState in detail
        if case .local(_, _, let lhsStreaming) = lhs,
           case .local(_, _, let rhsStreaming) = rhs {
            // Specifically check expandedThinkingBlocks
            if let lhsStreamingState = lhsStreaming,
               let rhsStreamingState = rhsStreaming {
                return lhsStreamingState.isComplete == rhsStreamingState.isComplete &&
                       lhsStreamingState.expandedThinkingBlocks == rhsStreamingState.expandedThinkingBlocks
            }
        }
        if case .anthropic(_, _, let lhsStreaming) = lhs,
           case .anthropic(_, _, let rhsStreaming) = rhs {
            if let lhsStreamingState = lhsStreaming,
               let rhsStreamingState = rhsStreaming {
                let res = lhsStreamingState.isComplete == rhsStreamingState.isComplete &&
                       lhsStreamingState.contentBlocks == rhsStreamingState.contentBlocks

                return res
            }
        }
        return true
    }
}
