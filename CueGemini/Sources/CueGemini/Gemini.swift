import Foundation
import os.log
import CueCommon

public let log = Logger(subsystem: "GeminiClient", category: "Gemini")

@MainActor
public struct Gemini {
    // MARK: - Configuration
    public struct Configuration {
        public let apiKey: String
        public let baseURL: URL

        public init(apiKey: String, baseURL: URL = URL(string: "https://generativelanguage.googleapis.com/v1beta")!) {
            self.apiKey = apiKey
            self.baseURL = baseURL
        }
    }
    
    public enum ChatModel: String, CaseIterable {
        case gemini20FlashExp = "gemini-2.0-flash-exp"
        case gemini20Pro = "gemini-2.0-pro-exp-02-05"

        public var id: String {
            return self.rawValue
        }

        public var displayName: String {
            switch self {
            case .gemini20FlashExp: return "Gemini 2.0 Flash Exp"
            case .gemini20Pro: return "Gemini 2.0 Pro Exp"
            }
        }
    }

    // MARK: - Errors
    public struct APIError: Decodable, Sendable {
        public let error: ErrorDetails

        public struct ErrorDetails: Decodable, Sendable {
            public let code: Int
            public let message: String
            public let status: String
            public let details: [ErrorDetail]

            public struct ErrorDetail: Decodable, Sendable {
                enum CodingKeys: String, CodingKey {
                    case type = "@type"
                    case reason
                    case domain
                    case metadata
                    case locale
                    case message
                }

                public let type: String
                public let reason: String?
                public let domain: String?
                public let metadata: [String: String]?
                public let locale: String?
                public let message: String?
            }
        }
    }

    public enum Error: Swift.Error {
        case invalidURL
        case invalidResponse
        case networkError(Swift.Error)
        case decodingError(DecodingError)
        case apiError(APIError)
        case unexpectedAPIResponse(String)
    }
    
    /// https://ai.google.dev/api/generate-content#method:-models.generatecontent
    /// https://github.com/google-gemini/generative-ai-swift/blob/main/Sources/GoogleAI/GenerateContentRequest.swift
    public struct GeminiContentRequest: Encodable {
        let contents: [ModelContent]
        let tools: [JSONValue]?
        let toolConfigs: [String: JSONValue]?
        let systemInstruction: String?
        let generationConfig: GenerationConfig?
    }

    public struct MessageRequest: Codable {
        public let model: String
        public let maxTokens: Int
        public let messages: [ModelContent]
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
            messages: [ModelContent],
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
    public let chat: ChatAPI

    public init(apiKey: String, baseURL: URL = URL(string: "https://generativelanguage.googleapis.com/v1beta")!) {
        let config = Configuration(apiKey: apiKey, baseURL: baseURL)
        let client = GeminiClient(configuration: config)
        self.chat = ChatAPI(client: client)
    }
}

// MARK: - APIs
@MainActor
public struct ChatAPI {
    private let client: GeminiClient

    init(client: GeminiClient) {
        self.client = client
    }

    public func create(
        model: String = Gemini.ChatModel.gemini20FlashExp.id,
        maxTokens: Int = 1024,
        messages: [ModelContent],
        tools: [JSONValue]? = nil,
        toolChoice: [String: String]? = nil
    ) async throws -> GenerateContentResponse {
        return try await generateContent(model: model, messages: messages)
    }
    
    public func create(
        with request: Gemini.MessageRequest
    ) async throws -> GenerateContentResponse {
        return try await generateContent(messages: request.messages)
    }
    
    public func generateContent(
        model: String = Gemini.ChatModel.gemini20FlashExp.id,
        messages: [ModelContent],
        generationConfig: GenerationConfig? = nil,
        safetySettings: [SafetySetting]? = nil,
        tools: [Tool]? = nil,
        toolConfig: ToolConfig? = nil,
        systemInstruction: ModelContent? = nil,
        isStreaming: Bool = false
    ) async throws -> GenerateContentResponse {
        let request = GenerateContentRequest(
            model: model,
            contents: messages,
            generationConfig: generationConfig,
            safetySettings: safetySettings,
            tools: tools,
            toolConfig: toolConfig,
            systemInstruction: systemInstruction,
            isStreaming: isStreaming,
            options: RequestOptions()
        )
        return try await client.send(
            endpoint: "models/\(model):generateContent",
            method: "POST",
            body: request
        )
    }
}
