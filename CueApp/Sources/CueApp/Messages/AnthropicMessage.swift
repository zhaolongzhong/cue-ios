enum ContentType: String, Codable {
    case text
    case toolUse = "tool_use"
    case toolResult = "tool_result"
    case image
}

struct TextBlock: Codable {
    let text: String
    let type: String  // Will always be "text"
}

struct ToolUseBlock: Codable {
    let type: String  // Will always be "tool_use"
    let id: String
    let input: [String: JSONValue]
    let name: String

    enum CodingKeys: String, CodingKey {
        case type
        case id
        case input
        case name
    }
}

enum ContentBlock: Codable {
    case text(TextBlock)
    case toolUse(ToolUseBlock)

    private enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
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

    func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let block):
            try block.encode(to: encoder)
        case .toolUse(let block):
            try block.encode(to: encoder)
        }
    }

    init(content: String) {
        self = .text(TextBlock(text: content, type: "text"))
    }

    init(toolUseBlock: ToolUseBlock) {
        self = .toolUse(toolUseBlock)
    }
}

enum StopReason: String, Codable {
    case endTurn = "end_turn"
    case maxTokens = "max_tokens"
    case stopSequence = "stop_sequence"
    case toolUse = "tool_use"
}

struct CacheControl: Codable {
    let type: String
}

// MARK: - Common Models
struct PromptCachingBetaUsage: Codable {
    let cacheCreationInputTokens: Int?
    let cacheReadInputTokens: Int?
    let inputTokens: Int?
    let outputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

// MARK: - Anthropic Message Models
struct PromptCachingBetaMessage: Codable {
    let id: String
    let content: [ContentBlock]
    let model: String  // Assuming Model is an enum/string
    let role: String  // Will always be "assistant"
    let stopReason: String?
    let stopSequence: String?
    let type: String  // Will always be "message"
    let usage: PromptCachingBetaUsage

    enum CodingKeys: String, CodingKey {
        case id
        case content
        case model
        case role
        case stopReason = "stop_reason"
        case stopSequence = "stop_sequence"
        case type
        case usage
    }
}

typealias AnthropicMessage = PromptCachingBetaMessage

// MARK: - ToolResultContent
struct ToolResultContent: Codable {
    let isError: Bool
    let toolUseId: String
    let type: String
    let content: ResultContentBlock

    enum CodingKeys: String, CodingKey {
        case isError = "is_error"
        case toolUseId = "tool_use_id"
        case type
        case content
    }
}

struct ImageBlock: Codable {
    let type: String
    let mediaType: String // "image/jpeg", "image/png", "image/gif", "image/webp"
    let data: String // base64

    enum CodingKeys: String, CodingKey {
        case type
        case mediaType = "media_type"
        case data
    }
}

enum ResultContentBlock: Codable {
    case text(TextBlock)
    case imageBlock(ImageBlock)

    private enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
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

    func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let block):
            try block.encode(to: encoder)
        case .imageBlock(let block):
            try block.encode(to: encoder)
        }
    }

    init(content: String) {
        self = .text(TextBlock(text: content, type: "text"))
    }
}

extension JSONValue {
    func toAnthropicMessage() -> AnthropicMessage? {
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
