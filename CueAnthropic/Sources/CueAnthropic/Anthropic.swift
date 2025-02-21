import Foundation
import os.log
import CueCommon

public let log = Logger(subsystem: "anthropic", category: "anthropic")

@MainActor
public struct Anthropic {
    // MARK: - Configuration
    public struct Configuration {
        public let apiKey: String
        public let baseURL: URL

        public init(apiKey: String, baseURL: URL = URL(string: "https://api.anthropic.com/v1")!) {
            self.apiKey = apiKey
            self.baseURL = baseURL
        }
    }

    // MARK: - Errors
    public struct APIError: Decodable, Sendable {
        public let error: ErrorDetails

        public struct ErrorDetails: Decodable, Sendable {
            public let message: String
            public let type: String
        }
    }

    public enum Error: Swift.Error {
        case invalidResponse
        case networkError(Swift.Error)
        case decodingError(DecodingError)
        case apiError(APIError)
        case unexpectedAPIResponse(String)
    }

    // MARK: - Message Types
    public struct MessageParam: Codable, Sendable {
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

    public struct ToolResultMessage: Codable, Sendable {
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

    public enum ChatMessageParam: Codable, Sendable, Identifiable {
        case userMessage(MessageParam)
        case assistantMessage(MessageParam)
        case toolMessage(ToolResultMessage)

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
                return message.content[0].text
            case .toolMessage(let message):
                return message.content[0].content[0].text
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

    public struct MessageRequest: Codable {
        public let model: String
        public let maxTokens: Int
        public let messages: [ChatMessageParam]
        public let tools: [JSONValue]?
        public let toolChoice: [String: String]?

        enum CodingKeys: String, CodingKey {
            case model
            case maxTokens = "max_tokens"
            case messages
            case tools
            case toolChoice = "tool_choice"
        }

        public init(
            model: String,
            maxTokens: Int,
            messages: [ChatMessageParam],
            tools: [JSONValue]? = nil,
            toolChoice: [String: String]? = nil
        ) {
            self.model = model
            self.maxTokens = maxTokens
            self.messages = messages
            self.tools = tools
            self.toolChoice = toolChoice
        }
    }

    // MARK: - Public Interface
    public let messages: MessagesAPI

    public init(apiKey: String, baseURL: URL = URL(string: "https://api.anthropic.com/v1")!) {
        let config = Configuration(apiKey: apiKey, baseURL: baseURL)
        let client = AnthropicClient(configuration: config)
        self.messages = MessagesAPI(client: client)
    }
}

// MARK: - APIs
@MainActor
public struct MessagesAPI {
    private let client: AnthropicClient

    init(client: AnthropicClient) {
        self.client = client
    }

    public func create(
        model: String = "claude-3-opus-20240229",
        maxTokens: Int = 1024,
        messages: [Anthropic.ChatMessageParam],
        tools: [JSONValue]? = nil,
        toolChoice: [String: String]? = nil
    ) async throws -> Anthropic.AnthropicMessage {
        let request = Anthropic.MessageRequest(
            model: model,
            maxTokens: maxTokens,
            messages: messages,
            tools: tools,
            toolChoice: toolChoice
        )

        return try await client.send(
            endpoint: "messages",
            method: "POST",
            body: request
        )
    }
}
