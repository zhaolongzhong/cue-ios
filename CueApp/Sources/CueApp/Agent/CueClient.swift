import Foundation
import CueCommon
import CueOpenAI
import CueAnthropic

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

// MARK: - Models
public enum CueChatMessage: Encodable, Sendable, Identifiable {
    case openAI(OpenAI.ChatMessageParam)
    case anthropic(Anthropic.ChatMessageParam)

    public var id: String {
        switch self {
        case .openAI(let msg):
            return msg.id
        case .anthropic(let msg):
            return msg.id
        }
    }

    var role: String {
        switch self {
        case .openAI(let msg): return msg.role
        case .anthropic(let msg): return msg.role
        }
    }

    var content: String {
        switch self {
        case .openAI(let msg): return msg.content
        case .anthropic(let msg): return msg.content
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .openAI(let msg):
            try container.encode(msg)
        case .anthropic(let msg):
            try container.encode(msg)
        }
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
    let maxTokens: Int?
    let temperature: Double?
    let maxTurns: Int

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
    }

    init(
        model: String,
        messages: [CueChatMessage] = [],
        conversationId: String? = nil,
        parentMessageId: String? = nil,
        websocketRequestId: String? = nil,
        maxTokens: Int = 1000,
        temperature: Double = 1.0,
        tools: [JSONValue]? = nil,
        toolChoice: String? = nil,
        maxTurns: Int = 30
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
    }
}

public struct CueCompletionResponse: Decodable, Sendable {
    public let content: CueContent?
    public let author: Author?
    public let metadata: Metadata?
    public let parentId: String?
    public let conversationId: String?

    enum RootKeys: String, CodingKey {
        case model
        case chatCompletion = "chat_completion"
        case anthropicMessage = "anthropic_message"
        case usage
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: RootKeys.self)
        // Decode the chat_completion object
        if let chatCompletion = try container.decodeIfPresent(OpenAI.ChatCompletion.self, forKey: .chatCompletion),
           let choice = chatCompletion.choices.first {
            // Create a CueContent from the first choice message
            self.content = CueContent(
                type: "chat",
                content: choice.message.content ?? "",
                chatCompletionMessage: nil,
                anthropicMessage: nil,
                chatCompletion: chatCompletion
            )
        } else if let anthropicMessage = try container.decodeIfPresent(Anthropic.AnthropicMessage.self, forKey: .anthropicMessage) {
            self.content = CueContent(
                type: "anthropic",
                content: anthropicMessage.content.first?.text ?? "",
                chatCompletionMessage: nil,
                anthropicMessage: anthropicMessage,
                chatCompletion: nil
            )
        } else {
            self.content = nil
        }
        // You can similarly map other keys if needed.
        self.author = nil
        self.metadata = nil
        self.parentId = nil
        self.conversationId = nil
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
    public let chatCompletion: OpenAI.ChatCompletion?

    enum CodingKeys: String, CodingKey {
        case type
        case content
        case chatCompletionMessage = "chat_completion_message"
        case anthropicMessage = "anthropic_message"
        case chatCompletion = "chat_completion"
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
