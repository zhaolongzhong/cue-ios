//
//  MessageRequest.swift
//  CueAnthropic
//

import CueCommon

extension Anthropic {
    public struct MessageRequest: Codable {
        public let model: String
        public let maxTokens: Int
        public let messages: [ChatMessageParam]
        public let tools: [JSONValue]?
        public let toolChoice: [String: String]?
        public let thinking: Thinking?
        public let stream: Bool?

        enum CodingKeys: String, CodingKey {
            case model
            case maxTokens = "max_tokens"
            case messages
            case tools
            case toolChoice = "tool_choice"
            case thinking
            case stream
        }

        public init(
            model: String,
            maxTokens: Int,
            messages: [ChatMessageParam],
            tools: [JSONValue]? = nil,
            toolChoice: [String: String]? = nil,
            stream: Bool = false,
            thinking: Thinking? = nil
        ) {
            self.model = model
            self.maxTokens = maxTokens
            self.messages = messages
            self.tools = tools
            self.toolChoice = toolChoice
            self.stream = stream
            self.thinking = thinking
        }
    }

    // MARK: - Message Param
    public struct MessageParam: Codable, Equatable, Sendable {
        public let role: String
        public let content: [ContentBlock]

        public init(role: String, content: [ContentBlock]) {
            self.role = role
            self.content = content
        }

        public var hasToolUse: Bool {
            content.contains { $0.isToolUse }
        }
    }

    public struct ToolResultMessage: Codable, Equatable, Sendable {
        public let role: String
        public let content: [ToolResultContent]

        public init(role: String, content: [ToolResultContent]) {
            self.role = role
            self.content = content
        }

        enum CodingKeys: String, CodingKey {
            case role
            case content
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            role = try container.decode(String.self, forKey: .role)
            content = try container.decode([ToolResultContent].self, forKey: .content)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(role, forKey: .role)
            try container.encode(content, forKey: .content)
        }
    }

    public struct Thinking: Codable, Sendable {
        public let type: String
        public let budgetTokens: Int

        public init(type: String, budgetTokens: Int) {
            self.type = type
            self.budgetTokens = budgetTokens
        }

        enum CodingKeys: String, CodingKey {
            case type
            case budgetTokens = "budget_tokens"
        }
    }
}
