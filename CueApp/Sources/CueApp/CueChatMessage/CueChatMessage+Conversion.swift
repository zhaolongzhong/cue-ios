//
//  CueChatMessage+Conversion.swift
//  CueApp
//

import Foundation
import CueCommon
import CueOpenAI
import CueAnthropic
import CueGemini

extension CueChatMessage {
    public var id: String {
        switch self {
        case .local(let msg, let stableId, _):
            return stableId ?? msg.id
        case .openAI(let msg, let stableId, _):
            return stableId ?? msg.id
        case .anthropic(let msg, let stableId, _):
            return stableId ?? msg.id
        case .gemini(let msg, let stableId, _):
            return stableId ?? msg.id
        case .cue(let msg, let stableId, _):
            return stableId ?? msg.id
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
        case .openAI(let msg, _, _): return msg.role
        case .anthropic(let msg, _, _): return msg.role
        case .gemini(let msg, _, _): return msg.role
        case .cue(let msg, _, _): return msg.author.role
        }
    }

    var content: OpenAI.ContentValue {
        switch self {
        case .local(let msg, _, _): return msg.content
        case .openAI(let msg, _, _): return msg.content
        case .anthropic(let msg, _, _): return .string(msg.content)
        case .gemini(let msg, _, _): return .string(msg.content)
        case .cue(let msg, _, _): return .string(msg.content.text)
        }
    }

    var contentType: MessageContentType {
        switch self {
        case .local(let msg, _, _):
            if case .assistantMessage(let message, _) = msg {
                if message.hasToolCall {
                    return .toolCall
                }
            } else if case .toolMessage = msg {
                return .toolMessage
            }
        case .openAI(let msg, _, _):
            if case .assistantMessage(let message, _) = msg {
                if message.hasToolCall {
                    return .toolCall
                }
            } else if case .toolMessage = msg {
                return .toolMessage
            }
        case .anthropic(let msg, _, _):
            if case .assistantMessage(let message, _) = msg {
                if message.hasToolUse {
                    return .toolUse
                }
            } else if case .toolMessage = msg {
                return .toolMessage
            }
        case .gemini(let msg, _, _):
            if case .assistantMessage = msg {
                if msg.hasFunctionCalls {
                    return .toolCall
                }
            } else if case .toolMessage = msg {
                return .toolMessage
            }
        case .cue(let msg, _, _):
            return msg.content.type ?? .text
        }
        return .text
    }

    var isUser: Bool {
        switch self {
        case .local(let msg, _, _):
            return msg.role == "user"
        case .openAI(let msg, _, _):
            return msg.role == "user"
        case .anthropic(let msg, _, _):
            if case .userMessage = msg {
                return true
            }
            return false
        case .gemini(let msg, _, _):
            if case .userMessage = msg {
                return true
            }
            return false
        case .cue(let msg, _, _):
            return msg.isUser
        }
    }

    var isTool: Bool {
        switch self {
        case .local(let msg, _, _):
            if case .assistantMessage(let message, _) = msg {
                return message.hasToolCall
            }
        case .openAI(let msg, _, _):
            if case .assistantMessage(let message, _) = msg {
                return message.hasToolCall
            }
        case .anthropic(let msg, _, _):
            if case .assistantMessage(let message, _) = msg {
                return message.hasToolUse
            }
        case .gemini(let msg, _, _):
            if case .assistantMessage = msg {
                return msg.hasFunctionCalls
            }
        case .cue(let msg, _, _):
            return msg.isTool
        }
        return false
    }

    var isToolMessage: Bool {
        switch self {
        case .local(let msg, _, _):
            if case .toolMessage = msg {
                return true
            }
        case .openAI(let msg, _, _):
            if case .toolMessage = msg {
                return true
            }
        case .anthropic(let msg, _, _):
            if case .toolMessage = msg {
                return true
            }
        case .gemini(let msg, _, _):
            if case .toolMessage = msg {
                return true
            }
        case .cue(let msg, _, _):
            return msg.isToolMessage
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
            case .openAI(let msg, _, _):
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
            case .gemini(let msg, _, _):
                if case .toolMessage(let toolMessage) = msg {
                    if case .functionResponse(let response) = toolMessage.parts.first {
                        if case .string(let content) = response.response["content"] {
                            return content
                        }
                    }
                }
                return msg.content
            case .cue(let msg, _, _):
                return msg.content.text
            }
        }()

        return JSONFormatter.prettyToolResult(content)
    }

    var toolName: String? {
        switch self {
        case .local(let msg, _, _):
            return msg.toolName
        case .openAI(let msg, _, _):
            return msg.toolName
        case .anthropic(let msg, _, _):
            return msg.toolName
        case .gemini(let msg, _, _):
            return msg.toolName
        case .cue(let msg, _, _):
            return msg.content.toolName
        }
    }

    var toolArgs: String? {
        switch self {
        case .local(let msg, _, _):
            return msg.toolArgs
        case .openAI(let msg, _, _):
            return msg.toolArgs
        case .anthropic(let msg, _, _):
            return msg.toolArgs
        case .gemini(let msg, _, _):
            return msg.toolArgs
        case .cue(let msg, _, _):
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

    var stableId: String? {
        switch self {
        case .local(_, let stableId, _):
            return stableId
        case .openAI(_, let stableId, _):
            return stableId
        case .anthropic(_, let stableId, _):
            return stableId
        case .gemini(_, let stableId, _):
            return stableId
        case .cue(_, let stableId, _):
            return stableId
        }
    }

    var openAIChatParam: OpenAI.ChatMessageParam? {
        switch self {
        case .local(let msg, _, _):
            return msg
        case .openAI(let msg, _, _):
            return msg
        default:
            return nil
        }
    }

    var geminiChatParam: Gemini.ChatMessageParam? {
        switch self {
        case .gemini(let msg, _, _):
            return msg
        default:
            return nil
        }
    }
}
