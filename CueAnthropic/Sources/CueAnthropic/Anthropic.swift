import Foundation
import os.log
import CueCommon

public let log = Logger(subsystem: "anthropic", category: "anthropic")

@MainActor
public struct Anthropic {
    public enum Models {
        public static let sonnet37 = "claude-3-7-sonnet-20250219"
        public static let opus = "claude-3-opus-20240229"
        public static let haiku = "claude-3-5-haiku-20240307"
    }

    // MARK: - Configuration
    public struct Configuration {
        public let apiKey: String
        public let baseURL: URL

        public init(apiKey: String, baseURL: URL = URL(string: "https://api.anthropic.com/v1")!) {
            self.apiKey = apiKey
            self.baseURL = baseURL
        }
    }

    // MARK: - Public Interface
    public let messages: MessagesAPI

    public init(apiKey: String, baseURL: URL = URL(string: "https://api.anthropic.com/v1")!) {
        let config = Configuration(apiKey: apiKey, baseURL: baseURL)
        let client = AnthropicHTTPClient(configuration: config)
        self.messages = MessagesAPI(client: client)
    }
}

// MARK: - APIs
@MainActor
public struct MessagesAPI {
    public let httpClient: AnthropicHTTPClient

    public init(client: AnthropicHTTPClient) {
        self.httpClient = client
    }

    public func create(
        model: String = "claude-3-7-sonnet-20250219",
        maxTokens: Int = 1024,
        messages: [Anthropic.ChatMessageParam],
        tools: [JSONValue]? = nil,
        toolChoice: [String: String]? = nil,
        stream: Bool = false
    ) async throws -> Anthropic.AnthropicMessage {
        let request = Anthropic.MessageRequest(
            model: model,
            maxTokens: maxTokens,
            messages: messages,
            tools: tools,
            toolChoice: toolChoice
        )

        return try await httpClient.send(
            endpoint: "messages",
            method: "POST",
            body: request
        )
    }

    public func createStream(
        model: String = "claude-3-opus-20240229",
        maxTokens: Int = 1024,
        messages: [Anthropic.ChatMessageParam],
        tools: [JSONValue]? = nil,
        toolChoice: [String: String]? = nil,
        stream: Bool = false,
        thinking: Anthropic.Thinking? = nil
    ) -> (
        events: AsyncThrowingStream<ServerStreamingEvent, Error>,
        connectionState: AsyncStream<ServerStreamingEvent.ConnectionState>,
        cancel: () -> Void
    ) {
        let request = Anthropic.MessageRequest(
            model: model,
            maxTokens: maxTokens,
            messages: messages,
            tools: tools,
            toolChoice: toolChoice,
            thinking: model == Anthropic.Models.sonnet37 ? thinking : nil
        )

        return httpClient.streamMessage(request: request)
    }
}
