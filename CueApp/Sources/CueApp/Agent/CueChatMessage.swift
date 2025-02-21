import Foundation
import CueCommon
import CueOpenAI
import CueAnthropic
import CueGemini

public enum CueChatMessage: Encodable, Sendable, Identifiable {
    case openAI(OpenAI.ChatMessageParam)
    case anthropic(Anthropic.ChatMessageParam)
    case gemini(Gemini.ChatMessageParam)
    case cue(MessageModel)

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .openAI(let msg):
            try container.encode(msg)
        case .anthropic(let msg):
            try container.encode(msg)
        case .gemini(let msg):
            try container.encode(msg)
        case .cue(let msg):
            try container.encode(msg)
        }
    }

    public var id: String {
        switch self {
        case .openAI(let msg):
            return msg.id
        case .anthropic(let msg):
            return msg.id
        case .gemini(let msg):
            return String(describing: msg)
        case .cue(let msg):
            return msg.id
        }
    }

    var role: String {
        switch self {
        case .openAI(let msg): return msg.role
        case .anthropic(let msg): return msg.role
        case .gemini(let msg): return msg.role
        case .cue(let msg): return msg.author.role
        }
    }

    var content: String {
        switch self {
        case .openAI(let msg): return msg.content
        case .anthropic(let msg): return msg.content
        case .gemini(let msg): return msg.content
        case .cue(let msg): return msg.content.text
        }
    }

    var isUser: Bool {
        switch self {
        case .openAI(let msg): return msg.role == "user"
        case .anthropic(let msg):
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
        case .openAI(let msg):
            if case .assistantMessage(let message) = msg {
                return message.hasToolCall
            }
        case .anthropic(let msg):
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
        case .openAI(let msg):
            if case .toolMessage = msg {
                return true
            }
        case .anthropic(let msg):
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
            case .openAI(let msg):
                if case .toolMessage(let toolMessage) = msg {
                    return toolMessage.content
                }
                return msg.content
            case .anthropic(let msg):
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
        case .openAI(let msg):
            return msg.toolName
        case .anthropic(let msg):
            return msg.toolName
        case .gemini(let msg):
            return msg.toolName
        case .cue(let msg):
            return msg.content.toolName
        }
    }

    var toolArgs: String? {
        switch self {
        case .openAI(let msg):
            return msg.toolArgs
        case .anthropic(let msg):
            return msg.toolArgs
        case .gemini(let msg):
            return msg.toolArgs
        case .cue(let msg):
            return msg.content.toolArgs
        }
    }
}

extension CueChatMessage: Equatable {
    public static func == (lhs: CueChatMessage, rhs: CueChatMessage) -> Bool {
        return lhs.id == rhs.id
    }
}
