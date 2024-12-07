import Foundation
import os.log

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
    public enum Error: Swift.Error {
        case invalidURL
        case networkError(Swift.Error)
        case invalidResponse
        case apiError(String)
        case decodingError(Swift.Error)
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
    private let client: OpenAIClient
    
    init(client: OpenAIClient) {
        self.client = client
    }
    
    public func create(
        model: String,
        messages: [OpenAI.MessageParam],
        maxTokens: Int = 1000,
        temperature: Double = 1.0
    ) async throws -> OpenAI.ChatCompletionResponse {
        let request = OpenAI.ChatCompletionRequest(
            model: model,
            messages: messages,
            maxTokens: maxTokens,
            temperature: temperature
        )
        
        return try await client.send(
            endpoint: "chat/completions",
            method: "POST",
            body: request
        )
    }
}
