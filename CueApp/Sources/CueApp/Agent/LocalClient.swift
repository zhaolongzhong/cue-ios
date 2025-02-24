import Foundation
import CueCommon
import CueOpenAI
import CueAnthropic
import CueGemini

// MARK: - Endpoint
enum LocalEndpoint: Endpoint {
    case chat(LocalRequest)

    var baseURL: String {
        return Provider.localBaseURL
    }

    var path: String {
        switch self {
        case .chat:
            return "/api/chat"
        }
    }

    var method: HTTPMethod {
        .post
    }

    var body: Data? {
        switch self {
        case .chat(let request):
            return try? JSONEncoder().encode(request)
        }
    }
}

@MainActor
public final class LocalClient {
    private let networkClient: NetworkClient

    public init(baseUrl: String? = nil) {
        if let baseUrl = baseUrl {
            Provider.localBaseURL = baseUrl
        }
        self.networkClient = NetworkClient.shared
    }

    public func send(
        model: String,
        stream: Bool = false,
        messages: [OpenAI.ChatMessageParam],
        tools: [JSONValue]? = nil,
        toolChoice: String? = nil
    ) async throws -> LocalResponse {
        let request = LocalRequest(
            model: model,
            stream: stream,
            messages: messages,
            tools: tools,
            toolChoice: toolChoice
        )

        let endpoint = LocalEndpoint.chat(request)
        return try await networkClient.request(endpoint)
    }
}

public struct LocalRequest: Encodable {
    let model: String
    let stream: Bool
    let messages: [OpenAI.ChatMessageParam]
    let tools: [JSONValue]?
    let toolChoice: String?

    enum CodingKeys: String, CodingKey {
        case model
        case stream
        case messages
        case tools
        case toolChoice = "tool_choice"
    }

    init(
        model: String,
        stream: Bool = false,
        messages: [OpenAI.ChatMessageParam] = [],
        tools: [JSONValue]? = nil,
        toolChoice: String? = nil
    ) {
        self.model = model
        self.stream = stream
        self.messages = messages
        self.tools = tools
        self.toolChoice = toolChoice
    }
}

public struct LocalResponse: Decodable, Sendable, DebugPrintable {
    public let model: String
    public let createdAt: Date
    public let message: OpenAI.AssistantMessage
    public let doneReason: String?
    public let done: Bool
    public let totalDuration: Int64
    public let loadDuration: Int64
    public let promptEvalCount: Int
    public let promptEvalDuration: Int64
    public let evalCount: Int
    public let evalDuration: Int64

    enum CodingKeys: String, CodingKey {
        case model
        case createdAt = "created_at"
        case message
        case doneReason = "done_reason"
        case done
        case totalDuration = "total_duration"
        case loadDuration = "load_duration"
        case promptEvalCount = "prompt_eval_count"
        case promptEvalDuration = "prompt_eval_duration"
        case evalCount = "eval_count"
        case evalDuration = "eval_duration"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.model = try container.decode(String.self, forKey: .model)

        let dateString = try container.decode(String.self, forKey: .createdAt)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: dateString) {
            self.createdAt = date
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .createdAt,
                in: container,
                debugDescription: "Failed to parse date: \(dateString)"
            )
        }

        self.message = try container.decode(OpenAI.AssistantMessage.self, forKey: .message)
        self.doneReason = try container.decodeIfPresent(String.self, forKey: .doneReason)
        self.done = try container.decode(Bool.self, forKey: .done)
        self.totalDuration = try container.decode(Int64.self, forKey: .totalDuration)
        self.loadDuration = try container.decode(Int64.self, forKey: .loadDuration)
        self.promptEvalCount = try container.decode(Int.self, forKey: .promptEvalCount)
        self.promptEvalDuration = try container.decode(Int64.self, forKey: .promptEvalDuration)
        self.evalCount = try container.decode(Int.self, forKey: .evalCount)
        self.evalDuration = try container.decode(Int64.self, forKey: .evalDuration)
    }
}

extension LocalResponse: Identifiable {
    public var id: String {
        UUID().uuidString
    }
}

public struct LocalMessage: Codable, Sendable, DebugPrintable {
    public let role: String
    public let content: String

    enum CodingKeys: String, CodingKey {
        case role
        case content
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.role = try container.decode(String.self, forKey: .role)
        self.content = try container.decode(String.self, forKey: .content)
    }
}

/// Single stream chunk
public struct LocalStreamChunk: Decodable, Equatable, Sendable {
    public let model: String
    public let createdAt: Date
    public let message: OpenAI.AssistantMessage
    public let done: Bool

    enum CodingKeys: String, CodingKey {
        case model
        case createdAt = "created_at"
        case message
        case done
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.model = try container.decode(String.self, forKey: .model)

        let dateString = try container.decode(String.self, forKey: .createdAt)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: dateString) {
            self.createdAt = date
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .createdAt,
                in: container,
                debugDescription: "Failed to parse date: \(dateString)"
            )
        }

        self.message = try container.decode(OpenAI.AssistantMessage.self, forKey: .message)
        self.done = try container.decode(Bool.self, forKey: .done)
    }
}

extension LocalClient {
    public func sendStream(
        model: String,
        messages: [OpenAI.ChatMessageParam],
        tools: [JSONValue]? = nil,
        toolChoice: String? = nil,
        onChunk: @escaping @MainActor (LocalStreamChunk) -> Void
    ) async throws {
        let request = LocalRequest(
            model: model,
            stream: true,
            messages: messages,
            tools: tools,
            toolChoice: toolChoice
        )

        let endpoint = LocalEndpoint.chat(request)

        try await networkClient.requestStream(endpoint) { @Sendable (chunk: LocalStreamChunk) in
            // Create a copy of the chunk to ensure data isolation
            let isolatedChunk = chunk
            await MainActor.run {
                onChunk(isolatedChunk)
            }
        }
    }
}
