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
        case toolUseError(String)
    }

    // MARK: - Message Types
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
    public let client: AnthropicClient

    public init(client: AnthropicClient) {
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
