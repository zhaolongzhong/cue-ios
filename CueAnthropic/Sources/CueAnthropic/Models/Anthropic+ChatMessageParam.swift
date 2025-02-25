//
//  MessageParam.swift
//  CueAnthropic
//

extension Anthropic {
    public enum ChatMessageParam: Codable, Sendable, Identifiable {
        case userMessage(MessageParam)
        case assistantMessage(MessageParam)
        case toolMessage(ToolResultMessage)

        private enum CodingKeys: String, CodingKey {
            case role, content, toolCalls, toolCallId
        }

        // Implement encoding/decoding logic as needed
        public func encode(to encoder: Encoder) throws {
            _ = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .userMessage(let message):
                try message.encode(to: encoder)
            case .assistantMessage(let message):
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
                self = .assistantMessage(try MessageParam(from: decoder))
            default:
                throw DecodingError.dataCorruptedError(forKey: .role, in: container, debugDescription: "Unknown role type")
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
            case .assistantMessage(let message):
                if message.content.isEmpty {
                    return ""
                }
                return message.content[0].text
            case .toolMessage(let message):
                return message.content[0].content[0].text
            }
        }

        public var contentBlocks: [ContentBlock] {
            switch self {
            case .userMessage(let message):
                return message.content
            case .assistantMessage(let message):
                if message.content.isEmpty {
                    return []
                }
                return message.content
            case .toolMessage(let message):
                return message.content[0].content
            }
        }

        public var id: String {
            switch self {
            case .userMessage(let message):
                return "user_\(message)"
            case .assistantMessage(let message):
                return "assistant_\(message)"
            case .toolMessage(let message):
                return "tool_\(message)"
            }
        }

        public var toolUses: [ToolUseBlock] {
            switch self {
            case .assistantMessage(let message):
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

        public var toolName: String? {
            return toolUses.map {
                $0.name
            }.joined(separator: ", ")
        }

        public var toolArgs: String? {
            return toolUses.map { $0.prettyInput }.joined(separator: ", ")
        }
    }
}

extension Anthropic.ChatMessageParam {
    public func hasToolUse() -> Bool {
        switch self {
        case .assistantMessage(let param):
            return param.content.contains { contentBlock in
                if case .toolUse = contentBlock {
                    return true
                }
                return false
            }
        default:
            return false
        }
    }

    public func isToolResult() -> Bool {
        switch self {
        case .toolMessage:
            return true
        default:
            return false
        }
    }

    public func hasContent() -> Bool {
        switch self {
        case .userMessage(let param):
            return !param.content.isEmpty
        case .assistantMessage(let param):
            return !param.content.isEmpty
        case .toolMessage(let param):
            return !param.content.isEmpty
        }
    }
}
