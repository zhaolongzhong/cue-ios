import Foundation
import CueCommon
import CueOpenAI
import CueAnthropic

public struct Author: Codable, Sendable {
    let role: String
    let name: String?
    let metadata: JSONValue?

    enum CodingKeys: String, CodingKey {
        case role
        case name
        case metadata
    }
}

public enum ContentDetail: Codable, Sendable {
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let arrayValue = try? container.decode([JSONValue].self) {
            self = .array(arrayValue)
        } else if let dictValue = try? container.decode([String: JSONValue].self) {
            self = .object(dictValue)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Content must be a string, array, or dictionary")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }
}

struct MessageContent: Codable, Sendable {
    let type: String?
    let content: ContentDetail
    let toolCalls: [ToolCall]?

    enum CodingKeys: String, CodingKey {
        case type
        case content
        case toolCalls = "tool_calls"
    }

    init(type: String?, content: ContentDetail, toolCalls: [ToolCall]?) {
        self.type = type
        self.content = content
        self.toolCalls = toolCalls
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Handle the case where content might be directly in the JSON
        if let directContent = try? container.decode(ContentDetail.self, forKey: .content) {
            self.content = directContent
        } else {
            // Fallback to handling the string content case
            self.content = .string("")
        }

        self.type = try container.decodeIfPresent(String.self, forKey: .type)

        if let toolCallsArray = try? container.decode([ToolCall].self, forKey: .toolCalls) {
            self.toolCalls = toolCallsArray
        } else if let rawToolCalls = try? container.decode([JSONValue].self, forKey: .toolCalls) {
            self.toolCalls = rawToolCalls.compactMap { jsonValue -> ToolCall? in
                guard case .object(let dict) = jsonValue,
                      let id = dict["id"]?.asString,
                      let type = dict["type"]?.asString,
                      case .object(let functionDict) = dict["function"] ?? .null,
                      let name = functionDict["name"]?.asString,
                      let arguments = functionDict["arguments"]?.asString else {
                    return nil
                }

                return ToolCall(
                    id: id,
                    type: type,
                    function: Function(name: name, arguments: arguments)
                )
            }
        } else {
            self.toolCalls = nil
        }
    }

    var toolUses: [Anthropic.ToolUseBlock]? {
        var toolUseBlocks: [Anthropic.ToolUseBlock] = []
        if case .array(let array) = self.content {
            for item in array {
                if case .object(let dict) = item,
                dict["type"]?.asString == "tool_use",
                case .object(let inputDict) = dict["input"] {
                    let toolUseBlock = Anthropic.ToolUseBlock(
                        type: "tool_use",
                        id: dict["id"]?.asString ?? "",
                        input: inputDict,
                        name: dict["name"]?.asString ?? ""
                    )
                    toolUseBlocks.append(toolUseBlock)
                }
            }
        }
        return toolUseBlocks.isEmpty ? nil : toolUseBlocks
    }
}

struct MessageMetadata: Codable, Sendable {
    let model: String?
    let usage: JSONValue?
    let payload: JSONValue?// original completion message and tool results

    enum CodingKeys: String, CodingKey {
        case model
        case usage
        case payload
    }
}

// MARK: - Message Model
public struct MessageModel: Codable, Identifiable, Sendable {
    public let id: String
    let conversationId: String
    let author: Author
    let content: MessageContent
    let metadata: MessageMetadata?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case author
        case content
        case metadata
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(String.self, forKey: .id) ?? "uuid_\(UUID().uuidString)"
        conversationId = try container.decodeIfPresent(String.self, forKey: .conversationId) ?? ""
        author = try container.decode(Author.self, forKey: .author)
        content = try container.decode(MessageContent.self, forKey: .content)
        metadata = try container.decodeIfPresent(MessageMetadata.self, forKey: .metadata)

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let createdAtString = try container.decode(String.self, forKey: .createdAt)
        if let date = dateFormatter.date(from: createdAtString) {
            createdAt = date
        } else {
            throw DecodingError.dataCorruptedError(forKey: .createdAt, in: container, debugDescription: "Date string does not match format")
        }

        let updatedAtString = try container.decode(String.self, forKey: .updatedAt)
        if let date = dateFormatter.date(from: updatedAtString) {
            updatedAt = date
        } else {
            throw DecodingError.dataCorruptedError(forKey: .updatedAt, in: container, debugDescription: "Date string does not match format")
        }
    }
}
