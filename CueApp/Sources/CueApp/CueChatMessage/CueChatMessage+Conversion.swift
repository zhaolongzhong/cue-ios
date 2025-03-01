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
        case .local(let msg, let stableId, _, _):
            return stableId ?? msg.id
        case .openAI(let msg, let stableId, _, _):
            return stableId ?? msg.id
        case .anthropic(let msg, let stableId, _, _):
            return stableId ?? msg.id
        case .gemini(let msg, let stableId, _, _):
            return stableId ?? msg.id
        case .cue(let msg, let stableId, _, _):
            return stableId ?? msg.id
        }
    }

    var stableId: String? {
        switch self {
        case .local(_, let stableId, _, _),
                .openAI(_, let stableId, _, _),
                .anthropic(_, let stableId, _, _),
                .gemini(_, let stableId, _, _),
                .cue(_, let stableId, _, _):
            return stableId
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

    static func streamingOpenAIMessage(
        id: String,
        streamingState: StreamingState
    ) -> Self {
        .openAI(
            .assistantMessage(
                .init(
                    role: Role.assistant.rawValue,
                    content: streamingState.content,
                    toolCalls: streamingState.toolCalls.count > 0 ? streamingState.toolCalls : nil
                )
            ),
            stableId: id,
            streamingState: streamingState
        )
    }

    var role: String {
        switch self {
        case .local(let msg, _, _, _): return msg.role
        case .openAI(let msg, _, _, _): return msg.role
        case .anthropic(let msg, _, _, _): return msg.role
        case .gemini(let msg, _, _, _): return msg.role
        case .cue(let msg, _, _, _): return msg.author.role
        }
    }

    var content: OpenAI.ContentValue {
        switch self {
        case .local(let msg, _, _, _): return msg.content
        case .openAI(let msg, _, _, _): return msg.content
        case .anthropic(let msg, _, _, _): return .string(msg.content)
        case .gemini(let msg, _, _, _): return .string(msg.content)
        case .cue(let msg, _, _, _): return .string(msg.content.text)
        }
    }

    var contentType: MessageContentType {
        if isTool {
            return .toolCall
        } else if isToolMessage {
            return .toolMessage
        }
        return .text
    }

    var isUser: Bool {
        switch self {
        case .local(let msg, _, _, _):
            return msg.role == "user"
        case .openAI(let msg, _, _, _):
            return msg.role == "user"
        case .anthropic(let msg, _, _, _):
            return msg.isUserMessage
        case .gemini(let msg, _, _, _):
            return msg.isUserMessage
        case .cue(let msg, _, _, _):
            return msg.isUser
        }
    }

    var isTool: Bool {
        switch self {
        case .local(let msg, _, _, _):
            return msg.hasToolCall
        case .openAI(let msg, _, let streamingState, _):
            return msg.hasToolCall || streamingState?.hasToolcall == true
        case .anthropic(let msg, _, _, _):
            return msg.hasToolUse || streamingState?.hasToolcall == true
        case .gemini(let msg, _, _, _):
            return msg.hasFunctionCall
        case .cue(let msg, _, _, _):
            return msg.isTool
        }
    }

    var isToolMessage: Bool {
        switch self {
        case .local(let msg, _, _, _),
                .openAI(let msg, _, _, _):
            return msg.isToolMessage
        case .anthropic(let msg, _, _, _):
            return msg.isToolMessage
        case .gemini(let msg, _, _, _):
            return msg.isToolMessage
        case .cue(let msg, _, _, _):
            return msg.isToolMessage
        }
    }

    var toolResultContent: String {
        let content: String = {
            switch self {
            case .local(let msg, _, _, _):
                if case .toolMessage(let toolMessage) = msg {
                    return toolMessage.content
                }
                return msg.content.contentAsString
            case .openAI(let msg, _, _, _):
                if case .toolMessage(let toolMessage) = msg {
                    return toolMessage.content
                }
                return msg.content.contentAsString
            case .anthropic(let msg, _, _, _):
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
            case .gemini(let msg, _, _, _):
                if case .toolMessage(let toolMessage) = msg {
                    if case .functionResponse(let response) = toolMessage.parts.first {
                        if case .string(let content) = response.response["content"] {
                            return content
                        }
                    }
                }
                return msg.content
            case .cue(let msg, _, _, _):
                return msg.content.text
            }
        }()

        return JSONFormatter.prettyToolResult(content)
    }

    var toolName: String? {
        switch self {
        case .local(let msg, _, _, _):
            return msg.toolName
        case .openAI(let msg, _, _, _):
            return msg.toolName
        case .anthropic(let msg, _, _, _):
            return msg.toolName
        case .gemini(let msg, _, _, _):
            return msg.toolName
        case .cue(let msg, _, _, _):
            return msg.content.toolName
        }
    }

    var toolArgs: String? {
        switch self {
        case .local(let msg, _, _, _):
            return msg.toolArgs
        case .openAI(let msg, _, _, _):
            return msg.toolArgs
        case .anthropic(let msg, _, _, _):
            return msg.toolArgs
        case .gemini(let msg, _, _, _):
            return msg.toolArgs
        case .cue(let msg, _, _, _):
            return msg.content.toolArgs
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

    var createdAt: Date? {
        switch self {
        case .local(_, _, _, let createdAt),
                .openAI(_, _, _, let createdAt),
                .anthropic(_, _, _, let createdAt),
                .gemini(_, _, _, let createdAt),
                .cue(_, _, _, let createdAt):
            return createdAt
        }
    }

    var openAIChatParam: OpenAI.ChatMessageParam? {
        switch self {
        case .local(let msg, _, _, _),
                .openAI(let msg, _, _, _):
            return msg
        default:
            return nil
        }
    }

    var anthropicChatParam: Anthropic.ChatMessageParam? {
        switch self {
        case .anthropic(let msg, _, _, _):
            return msg
        default:
            return nil
        }
    }

    var geminiChatParam: Gemini.ChatMessageParam? {
        switch self {
        case .gemini(let msg, _, _, _):
            return msg
        default:
            return nil
        }
    }
}
