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
    
    // MARK: - Public Interface
    public let chat: ChatAPI
    
    public init(apiKey: String, baseURL: URL = URL(string: "https://api.openai.com/v1")!) {
        let config = Configuration(apiKey: apiKey, baseURL: baseURL)
        let client = OpenAIHTTPClient(configuration: config)
        self.chat = ChatAPI(client: client)
    }
}

// MARK: - APIs
@MainActor
public struct ChatAPI {
    private let client: OpenAIHTTPClient
    
    init(client: OpenAIHTTPClient) {
        self.client = client
    }
    
    public var completions: Completions { Completions(client: client) }
}
