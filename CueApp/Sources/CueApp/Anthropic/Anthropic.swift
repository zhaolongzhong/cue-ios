import Foundation
import os.log

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

    public enum ChatMessage: Codable, Sendable, Identifiable {
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
                return "tool"
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
    }

    public struct MessageRequest: Codable {
        public let model: String
        public let maxTokens: Int
        public let messages: [ChatMessage]
        public let tools: [MCPTool]?
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
            messages: [ChatMessage],
            tools: [Tool]? = nil,
            toolChoice: [String: String]? = nil
        ) {
            self.model = model
            self.maxTokens = maxTokens
            self.messages = messages
            self.tools = tools
            self.toolChoice = toolChoice
        }
    }

    // MARK: - Tool Types (alias to OpenAI types)
    public typealias Tool = MCPTool

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
        messages: [Anthropic.ChatMessage],
        tools: [MCPTool]? = nil,
        toolChoice: [String: String]? = nil
    ) async throws -> AnthropicMessage {
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
