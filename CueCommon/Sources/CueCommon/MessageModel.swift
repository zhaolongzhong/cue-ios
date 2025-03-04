import Foundation

public struct MessageModel: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let conversationId: String
    public let author: Author
    public let content: MessageContent
    public let metadata: MessageMetadata?
    public let createdAt: Date
    public let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case author
        case content
        case metadata
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public init(
        id: String,
        conversationId: String,
        author: Author,
        content: MessageContent,
        metadata: MessageMetadata? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.conversationId = conversationId
        self.author = author
        self.content = content
        self.metadata = metadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
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

        let createdAtString = try container.decodeIfPresent(String.self, forKey: .createdAt)
        if let createdAtString, let date = dateFormatter.date(from: createdAtString) {
            createdAt = date
        } else {
            createdAt = Date()
        }

        let updatedAtString = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        if let updatedAtString, let date = dateFormatter.date(from: updatedAtString) {
            updatedAt = date
        } else {
            updatedAt = Date()
        }
    }
}

public struct Author: Codable, Equatable, Sendable {
    public let role: String
    public let name: String?
    public let metadata: JSONValue?

    enum CodingKeys: String, CodingKey {
        case role
        case name
        case metadata
    }

    public init(role: String, name: String? = nil, metadata: JSONValue? = nil) {
        self.role = role
        self.name = name
        self.metadata = metadata
    }
}

public struct MessageContent: Codable, Equatable, Sendable {
    public let type: MessageContentType?
    public let content: ContentDetail

    enum CodingKeys: String, CodingKey {
        case type = "content_type"
        case fallbackType = "type"
        case content = "parts"
        case fallbackContent = "content"
    }

    public init(type: MessageContentType? = .text, content: ContentDetail) {
        self.type = type
        self.content = content
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Try to decode type from multiple possible locations
        if let contentType = try container.decodeIfPresent(MessageContentType.self, forKey: .type) {
            type = contentType
        } else if let fallbackType = try container.decodeIfPresent(MessageContentType.self, forKey: .fallbackType) {
            type = fallbackType
        } else {
            // If we can't find a type, default to unknown
            type = .unknown
        }

        // Try to decode content from multiple possible locations
        if container.contains(.content) {
            do {
                content = try container.decode(ContentDetail.self, forKey: .content)
            } catch {
                // If content can't be decoded directly, try to create a default ContentDetail
                if let stringContent = try? container.decodeIfPresent(String.self, forKey: .content) {
                    content = .string(stringContent)
                } else {
                    // If all else fails, provide an empty string
                    content = .string("")
                }
            }
        } else if container.contains(.fallbackContent) {
            do {
                content = try container.decode(ContentDetail.self, forKey: .fallbackContent)
            } catch {
                if let stringContent = try? container.decodeIfPresent(String.self, forKey: .fallbackContent) {
                    content = .string(stringContent)
                } else {
                    // If all else fails, provide an empty string
                    content = .string("")
                }
            }
        } else {
            // Default empty content if none found
            content = .string("")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        // When encoding, use the primary keys
        try container.encodeIfPresent(type, forKey: .type)
        try container.encode(content, forKey: .content)
    }
}

public enum MessageContentType: String, Codable, Sendable {
    case text
    case image
    case toolCall = "tool_calls"
    case toolMessage = "tool_message"
    case toolUse = "tool_use"
    case toolResult = "tool_result"
    case unknown

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let stringValue = try? container.decode(String.self) {
            switch stringValue {
            case "text": self = .text
            case "image": self = .image
            case "tool_call", "tool_calls": self = .toolCall
            case "tool_message": self = .toolMessage
            case "tool_use": self = .toolUse
            case "tool_result": self = .toolResult
            default:
                print("Warning: Unknown MessageContentType value: \(stringValue)")
                self = .unknown
            }
        } else {
            self = .unknown
        }
    }
}

public enum ContentDetail: Codable, Equatable, Sendable {
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

public struct MessageMetadata: Codable, Equatable, Sendable {
    public let model: String?
    public let usage: JSONValue?
    public let payload: JSONValue?

    enum CodingKeys: String, CodingKey {
        case model
        case usage
        case payload
    }

    public init(model: String?, usage: JSONValue?, payload: JSONValue?) {
        self.model = model
        self.usage = usage
        self.payload = payload
    }
}
