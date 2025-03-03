import Foundation
import CueCommon
import CueOpenAI
import CueAnthropic
import CueGemini

// MARK: - Endpoint
enum CueEndpoint: Endpoint {
    case completions(CompletionRequest)
    case completionsCue(CompletionRequest)

    var path: String {
        switch self {
        case .completions:
            return "/chat/completions"
        case .completionsCue:
            return "/chat/completions/cue"
        }
    }

    var method: HTTPMethod {
        .post
    }

    var body: Data? {
        switch self {
        case .completions(let request), .completionsCue(let request):
            return try? JSONEncoder().encode(request)
        }
    }
}

@MainActor
public final class CueClient {
    private let networkClient: NetworkClient

    public init() {
        self.networkClient = NetworkClient.shared
    }

    public func send(
        model: String,
        messages: [CueChatMessage],
        conversationId: String? = nil,
        parentMessageId: String? = nil,
        websocketRequestId: String? = nil,
        tools: [JSONValue]? = nil,
        toolChoice: String? = nil,
        maxTokens: Int = 1000,
        temperature: Double = 1.0
    ) async throws -> CueCompletionResponse {
        let request = CompletionRequest(
            model: model,
            messages: messages,
            conversationId: conversationId,
            parentMessageId: parentMessageId,
            websocketRequestId: websocketRequestId,
            maxTokens: maxTokens,
            temperature: temperature,
            tools: tools,
            toolChoice: toolChoice
        )

        let endpoint = conversationId != nil ?
            CueEndpoint.completionsCue(request) :
            CueEndpoint.completions(request)
        return try await networkClient.request(endpoint)
    }
}

public struct CompletionRequest: Encodable {
    let model: String
    let messages: [CueChatMessage]
    let conversationId: String?
    let parentMessageId: String?
    let websocketRequestId: String?
    let tools: [JSONValue]?
    let toolChoice: String?
    let maxTokens: Int
    let temperature: Double?
    let maxTurns: Int
    let thinking: Anthropic.Thinking?
    let stream: Bool

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case conversationId = "conversation_id"
        case parentMessageId = "parent_message_id"
        case websocketRequestId = "websocket_request_id"
        case tools
        case toolChoice = "tool_choice"
        case maxTokens = "max_tokens"
        case temperature
        case maxTurns = "max_turns"
        case thinking
        case stream = "stream"
    }

    init(
        model: String,
        messages: [CueChatMessage] = [],
        conversationId: String? = nil,
        parentMessageId: String? = nil,
        websocketRequestId: String? = nil,
        maxTokens: Int = 10000,
        temperature: Double = 1.0,
        tools: [JSONValue]? = nil,
        toolChoice: String? = nil,
        maxTurns: Int = 30,
        thinking: Anthropic.Thinking? = nil,
        stream: Bool = false
    ) {
        self.model = model
        self.messages = messages
        self.conversationId = conversationId
        self.parentMessageId = parentMessageId
        self.websocketRequestId = websocketRequestId
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.tools = tools
        self.toolChoice = toolChoice
        self.maxTurns = maxTurns
        self.thinking = thinking
        self.stream = stream
    }
}

public struct CueCompletionResponse: Decodable, Sendable {
    public let content: CueContent?
    public let author: Author?
    public let metadata: Metadata?
    public let parentId: String?
    public let conversationId: String?

    enum RootKeys: String, CodingKey {
        case chatCompletion = "chat_completion"
        case anthropicMessage = "anthropic_message"
        case geminiMessage = "gemini_message"
        case model
        case usage
    }

    public init(content: CueContent? = nil) {
        self.content = content
        self.author = nil
        self.metadata = nil
        self.parentId = nil
        self.conversationId = nil
    }

    public init(from decoder: Decoder) throws {
        // First try to decode as direct model response (not nested)
        if let directModelResponse = try? Self.decodeDirectModelResponse(from: decoder) {
            self.content = directModelResponse
            self.author = nil
            self.metadata = nil
            self.parentId = nil
            self.conversationId = nil
            return
        }

        // If not a direct model response, try to decode from nested structure
        let container = try decoder.container(keyedBy: RootKeys.self)

        // Try to decode from each possible nested key
        if let chatCompletion = try container.decodeIfPresent(OpenAI.ChatCompletion.self, forKey: .chatCompletion),
           let choice = chatCompletion.choices.first {
            self.content = CueContent(
                type: "chat",
                content: choice.message.content ?? "",
                chatCompletionMessage: nil,
                anthropicMessage: nil,
                geminiMessage: nil,
                chatCompletion: chatCompletion
            )
        } else if let anthropicMessage = try container.decodeIfPresent(Anthropic.AnthropicMessage.self, forKey: .anthropicMessage) {
            self.content = CueContent(
                type: "anthropic",
                content: anthropicMessage.content.first?.text ?? "",
                chatCompletionMessage: nil,
                anthropicMessage: anthropicMessage,
                geminiMessage: nil,
                chatCompletion: nil
            )
        } else if let geminiMessage = try container.decodeIfPresent(ModelContent.self, forKey: .geminiMessage) {
            self.content = CueContent(
                type: "gemini",
                content: geminiMessage.parts.first?.text ?? "",
                chatCompletionMessage: nil,
                anthropicMessage: nil,
                geminiMessage: geminiMessage,
                chatCompletion: nil
            )
        } else {
            self.content = nil
        }

        self.author = nil
        self.metadata = nil
        self.parentId = nil
        self.conversationId = nil
    }

    // Helper method to try decoding direct model responses
    private static func decodeDirectModelResponse(from decoder: Decoder) throws -> CueContent? {
        let container = try decoder.singleValueContainer()

        if let chatCompletion = try? container.decode(OpenAI.ChatCompletion.self),
           let choice = chatCompletion.choices.first {
            return CueContent(
                type: "chat",
                content: choice.message.content ?? "",
                chatCompletionMessage: nil,
                anthropicMessage: nil,
                geminiMessage: nil,
                chatCompletion: chatCompletion
            )
        }

        if let anthropicMessage = try? container.decode(Anthropic.AnthropicMessage.self) {
            return CueContent(
                type: "anthropic",
                content: anthropicMessage.content.first?.text ?? "",
                chatCompletionMessage: nil,
                anthropicMessage: anthropicMessage,
                geminiMessage: nil,
                chatCompletion: nil
            )
        }

        if let geminiMessage = try? container.decode(ModelContent.self) {
            return CueContent(
                type: "gemini",
                content: geminiMessage.parts.first?.text ?? "",
                chatCompletionMessage: nil,
                anthropicMessage: nil,
                geminiMessage: geminiMessage,
                chatCompletion: nil
            )
        }

        // If none worked, return nil and fall back to next approach
        return nil
    }
}

extension CueCompletionResponse: Identifiable {
    public var id: String {
        UUID().uuidString
    }
}

public struct CueContent: Codable, Sendable {
    public let type: String
    public let content: String
    public let chatCompletionMessage: OpenAI.ChatMessageParam?
    public let anthropicMessage: Anthropic.AnthropicMessage?
    public let geminiMessage: ModelContent?
    public let chatCompletion: OpenAI.ChatCompletion?

    enum CodingKeys: String, CodingKey {
        case type
        case content
        case chatCompletionMessage = "chat_completion_message"
        case anthropicMessage = "anthropic_message"
        case chatCompletion = "chat_completion"
        case geminiMessage = "gemini_message"
    }
}

public struct TokenUsage: Codable {
    public let inputTokens: Int
    public let outputTokens: Int
    public let totalTokens: Int

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case totalTokens = "total_tokens"
    }
}
