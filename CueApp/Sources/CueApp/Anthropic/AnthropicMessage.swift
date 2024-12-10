public enum ContentType: String, Codable {
    case text
    case toolUse = "tool_use"
    case toolResult = "tool_result"
    case image
}

public struct TextBlock: Codable, Sendable {
    public let text: String
    public let type: String  // Will always be "text"

    public init(text: String, type: String) {
        self.text = text
        self.type = type
    }
}

public struct ToolUseBlock: Codable, Sendable {
    public let type: String  // Will always be "tool_use"
    public let id: String
    public let input: [String: JSONValue]
    public let name: String

    public enum CodingKeys: String, CodingKey {
        case type
        case id
        case input
        case name
    }

    public init(type: String, id: String, input: [String: JSONValue], name: String) {
        self.type = type
        self.id = id
        self.input = input
        self.name = name
    }
}

public enum ContentBlock: Codable, Sendable {
    case text(TextBlock)
    case toolUse(ToolUseBlock)

    private enum CodingKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "text":
            let block = try TextBlock(from: decoder)
            self = .text(block)
        case "tool_use":
            let block = try ToolUseBlock(from: decoder)
            self = .toolUse(block)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown type value: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let block):
            try block.encode(to: encoder)
        case .toolUse(let block):
            try block.encode(to: encoder)
        }
    }

    public init(content: String) {
        self = .text(TextBlock(text: content, type: "text"))
    }

    public init(toolUseBlock: ToolUseBlock) {
        self = .toolUse(toolUseBlock)
    }

    public var text: String {
        switch self {
        case .text(let text):
            return text.text
        case .toolUse(let toolUse):
            return String(describing: toolUse)
        }
    }
}

public enum StopReason: String, Codable {
    case endTurn = "end_turn"
    case maxTokens = "max_tokens"
    case stopSequence = "stop_sequence"
    case toolUse = "tool_use"
}

public struct CacheControl: Codable {
    public let type: String

    public init(type: String) {
        self.type = type
    }
}

// MARK: - Common Models
public struct PromptCachingBetaUsage: Codable {
    public let cacheCreationInputTokens: Int?
    public let cacheReadInputTokens: Int?
    public let inputTokens: Int?
    public let outputTokens: Int?

    public enum CodingKeys: String, CodingKey {
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }

    public init(
        cacheCreationInputTokens: Int?,
        cacheReadInputTokens: Int?,
        inputTokens: Int?,
        outputTokens: Int?
    ) {
        self.cacheCreationInputTokens = cacheCreationInputTokens
        self.cacheReadInputTokens = cacheReadInputTokens
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }
}

// MARK: - Anthropic Message Models
public struct PromptCachingBetaMessage: Codable {
    public let id: String
    public let content: [ContentBlock]
    public let model: String
    public let role: String
    public let stopReason: String?
    public let stopSequence: String?
    public let type: String
    public let usage: PromptCachingBetaUsage

    public enum CodingKeys: String, CodingKey {
        case id
        case content
        case model
        case role
        case stopReason = "stop_reason"
        case stopSequence = "stop_sequence"
        case type
        case usage
    }

    public init(
        id: String,
        content: [ContentBlock],
        model: String,
        role: String,
        stopReason: String?,
        stopSequence: String?,
        type: String,
        usage: PromptCachingBetaUsage
    ) {
        self.id = id
        self.content = content
        self.model = model
        self.role = role
        self.stopReason = stopReason
        self.stopSequence = stopSequence
        self.type = type
        self.usage = usage
    }
}

public typealias AnthropicMessage = PromptCachingBetaMessage

// MARK: - ToolResultContent
public struct ToolResultContent: Codable, Sendable {
    public let isError: Bool
    public let toolUseId: String
    public let type: String  // This should be "tool_result"
    public let content: [ContentBlock]

    public enum CodingKeys: String, CodingKey {
        case isError = "is_error"
        case toolUseId = "tool_use_id"
        case type
        case content
    }

    public init(
        isError: Bool,
        toolUseId: String,
        type: String,
        content: [ContentBlock]
    ) {
        self.isError = isError
        self.toolUseId = toolUseId
        self.type = type
        self.content = content
    }
}

public struct ImageBlock: Codable, Sendable {
    public let type: String
    public let mediaType: String
    public let data: String

    public enum CodingKeys: String, CodingKey {
        case type
        case mediaType = "media_type"
        case data
    }

    public init(type: String, mediaType: String, data: String) {
        self.type = type
        self.mediaType = mediaType
        self.data = data
    }
}

public enum ResultContentBlock: Codable, Sendable {
    case text(TextBlock)
    case imageBlock(ImageBlock)

    private enum CodingKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "text":
            let block = try TextBlock(from: decoder)
            self = .text(block)
        case "tool_use":
            let block = try ImageBlock(from: decoder)
            self = .imageBlock(block)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown type value: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let block):
            try block.encode(to: encoder)
        case .imageBlock(let block):
            try block.encode(to: encoder)
        }
    }

    public init(content: String) {
        self = .text(TextBlock(text: content, type: "text"))
    }

    public var text: String {
        switch self {
        case .text(let text):
            return text.text
        case .imageBlock:
            return String(describing: "image")
        }
    }
}

extension JSONValue {
    public func toAnthropicMessage() -> AnthropicMessage? {
        guard case .dictionary(let dict) = self else { return nil }

        // Extract required fields
        guard let id = dict["id"]?.asString,
              let model = dict["model"]?.asString,
              let role = dict["role"]?.asString,
              let type = dict["type"]?.asString,
              let stopReason = dict["stop_reason"]?.asString,
              case .array(let contentArray) = dict["content"] else {
            return nil
        }

        // Parse stop sequence (optional)
        let stopSequence = dict["stop_sequence"]?.asString

        // Parse content items
        let content: [ContentBlock?] = contentArray.map { contentValue -> ContentBlock? in
            guard case .dictionary(let contentDict) = contentValue,
                  let typeStr = contentDict["type"]?.asString else {
                return nil
            }

            // Parse based on content type
            switch typeStr {
            case "text":
                guard let text = contentDict["text"]?.asString else { return nil }
                return ContentBlock(content: text)

            case "tool_use":
                guard let id = contentDict["id"]?.asString,
                      let name = contentDict["name"]?.asString,
                      case .dictionary(let input)? = contentDict["input"] else {
                    return nil
                }

                return ContentBlock(toolUseBlock: ToolUseBlock(type: "tool_use", id: id, input: input, name: name))
            default:
                print("unexpected type")
            }
            return nil
        }

        // Parse usage
        let usage: PromptCachingBetaUsage?
        if case .dictionary(let usageDict) = dict["usage"] {
            usage = parseAnthropicUsage(from: usageDict)
        } else {
            usage = nil
        }

        guard let usage = usage else { return nil }

        return AnthropicMessage(
            id: id,
            content: content.compactMap { $0},
            model: model,
            role: role,
            stopReason: stopReason,
            stopSequence: stopSequence,
            type: type,
            usage: usage
        )
    }

    private func parseAnthropicUsage(from dict: [String: JSONValue]) -> PromptCachingBetaUsage? {
        return PromptCachingBetaUsage(
            cacheCreationInputTokens: dict["cache_creation_input_tokens"]?.asInt,
            cacheReadInputTokens: dict["cache_read_input_tokens"]?.asInt,
            inputTokens: dict["input_tokens"]?.asInt,
            outputTokens: dict["output_tokens"]?.asInt
        )
    }
}
