//
//  MessageParam.swift
//  CueAnthropic
//

extension Anthropic {
    public enum ChatMessageParam: Codable, Equatable, Sendable, Identifiable {
        case userMessage(MessageParam)
        case assistantMessage(MessageParam, AnthropicMessage? = nil)
        case toolMessage(ToolResultMessage)

        private enum CodingKeys: String, CodingKey {
            case role, content, toolCalls, toolCallId
        }

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
                do {
                    let messageParam = try MessageParam(from: decoder)
                    self = .userMessage(messageParam)
                } catch {
                    let toolResultMessage = try ToolResultMessage(from: decoder)
                    self = .toolMessage(toolResultMessage)
                }
            case "assistant":
                self = .assistantMessage(try MessageParam(from: decoder), nil)
            default:
                throw DecodingError.dataCorruptedError(forKey: .role, in: container, debugDescription: "Unknown role type")
            }
        }
    }
}

extension Anthropic.ChatMessageParam {
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
            return "user"
        }
    }

    public var content: String {
        switch self {
        case .userMessage(let message):
            return message.content[0].text
        case .assistantMessage(let message, _):
            let text = message.content.compactMap { block -> String? in
                if case .text(let textBlock) = block {
                    return textBlock.text
                }
                return nil
            }
            return text.joined(separator: "\n")
        case .toolMessage(let message):
            return message.content[0].content[0].text
        }
    }

    public var contentBlocks: [Anthropic.ContentBlock] {
        switch self {
        case .userMessage(let message):
            return message.content
        case .assistantMessage(let message, _):
            if message.content.isEmpty {
                return []
            }
            return message.content
        case .toolMessage(let message):
            return message.content[0].content
        }
    }

    public var toolUses: [Anthropic.ToolUseBlock] {
        switch self {
        case .assistantMessage(let message, _):
            let toolUses = message.content.filter { $0.isToolUse }
            if  toolUses.count > 0 {
                return toolUses.compactMap {
                    if case .toolUse(let toolUse) = $0 {
                        return toolUse
                    }
                    return nil
                }
            }
            return []
        default:
            return []
        }
    }

    public var toolMessage: Anthropic.ToolResultMessage? {
        switch self {
        case .toolMessage(let msg):
            return msg
        default:
            return nil
        }
    }

    public var toolName: String? {
        return toolUses.map {
            $0.name
        }.joined(separator: ", ")
    }

    public var toolArgs: String? {
        return toolUses.map { $0.prettyInput }.joined(separator: ", ")
    }

    public var hasToolUse: Bool {
        switch self {
        case .assistantMessage(let param, _):
            return param.hasToolUse
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

    public var isUserMessage: Bool {
        switch self {
        case .userMessage:
            return true
        default:
            return false
        }
    }

    public func toMessageParam(simple: Bool = false) -> Anthropic.ChatMessageParam {
        switch self {
        case .userMessage(let message):
            if simple {
                return .userMessage(message.toMessageParam(role: "user", simple: true))
            }
            return .userMessage(message)
        case .assistantMessage(let message, let contextId):
            if simple {
                return .assistantMessage(message.toMessageParam(role: "assistant", simple: true), contextId)
            }
            return .assistantMessage(message, contextId)
        case .toolMessage(let message):
            if simple {
                return .userMessage(message.toMessageParam())
            }
            return .toolMessage(message)
        }
    }
}

extension Anthropic.MessageParam {
    func toMessageParam(role: String, simple: Bool) -> Anthropic.MessageParam {
        if !simple {
            return self
        }

        var finalContent = ""
        for contentBlock in self.content {
            finalContent += contentBlock.text

        }
        let textBlock = Anthropic.ContentBlock.text(
            Anthropic.TextBlock(text: finalContent, type: "text")
        )
        return Anthropic.MessageParam(role: role, content: [textBlock])
    }
}

extension Anthropic.ToolResultMessage {
    func toMessageParam() -> Anthropic.MessageParam {
        var finalContent = ""
        for resultContentBlock in self.content {
            finalContent += resultContentBlock.toString()

        }
        let textBlock = Anthropic.ContentBlock.text(
            Anthropic.TextBlock(text: finalContent, type: "text")
        )
        return Anthropic.MessageParam(role: "user", content: [textBlock])
    }
}

extension Anthropic.ToolResultContent {
    func toString() -> String {
        var finalContent = "isError: \(self.isError), toolUserId:\(self.toolUseId), type: tool_result. content: "
        for contentBlock in self.content {
            finalContent += contentBlock.text

        }
        return finalContent
    }
}
