import Foundation
import os.log
import CueCommon

public let log = Logger(subsystem: "openai", category: "openai")

@MainActor
public struct OpenAI {
    // MARK: - Configuration
    public struct Configuration {
        public let apiKey: String
        public let baseURL: URL
        
        public init(apiKey: String, baseURL: URL = URL(string: "https://api.openai.com/v1")!) {
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
            public let param: String?
            public let code: String
        }
    }
    
    public enum Error: Swift.Error {
        case invalidResponse
        case networkError(Swift.Error)
        case decodingError(DecodingError)
        case apiError(APIError)
        case unexpectedAPIResponse(String)
    }
    
    // MARK: - Public Interface
    public let chat: ChatAPI
    
    public init(apiKey: String, baseURL: URL = URL(string: "https://api.openai.com/v1")!) {
        let config = Configuration(apiKey: apiKey, baseURL: baseURL)
        let client = OpenAIClient(configuration: config)
        self.chat = ChatAPI(client: client)
    }
}

// MARK: - APIs
@MainActor
public struct ChatAPI {
    private let client: OpenAIClient
    
    init(client: OpenAIClient) {
        self.client = client
    }
    
    public var completions: CompletionsAPI { CompletionsAPI(client: client) }
}

@MainActor
public struct CompletionsAPI {
    let client: OpenAIClient
    
    init(client: OpenAIClient) {
        self.client = client
    }
    
    public func create(
        model: String,
        messages: [OpenAI.ChatMessageParam],
        maxTokens: Int = 1000,
        temperature: Double = 1.0,
        tools: [JSONValue]? = nil,
        toolChoice: String? = nil
    ) async throws -> OpenAI.ChatCompletion {
        let request = OpenAI.ChatCompletionRequest(
            model: model,
            messages: messages,
            maxTokens: maxTokens,
            temperature: temperature,
            tools: tools,
            toolChoice: toolChoice
        )
        
        return try await client.send(
            endpoint: "chat/completions",
            method: "POST",
            body: request
        )
    }
}

extension OpenAI.Error: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from the server."
        case .networkError(let underlyingError):
            return "Network error: \(underlyingError.localizedDescription)"
        case .decodingError(let decodingError):
            return "Decoding error: \(decodingError.localizedDescription)"
        case .apiError(let apiError):
            return "API error: \(apiError.error.message) (Code: \(apiError.error.code), Type: \(apiError.error.type))"
        case .unexpectedAPIResponse(let message):
            return "Unexpected API response: \(message)"
        }
    }
}
