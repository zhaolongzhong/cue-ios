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

        if let contentType = try container.decodeIfPresent(MessageContentType.self, forKey: .type) {
            type = contentType
        } else {
            type = try container.decodeIfPresent(MessageContentType.self, forKey: .fallbackType)
        }

        if container.contains(.content) {
            content = try container.decode(ContentDetail.self, forKey: .content)
        } else {
            content = try container.decode(ContentDetail.self, forKey: .fallbackContent)
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
    case toolCall = "tool_call"
    case toolMessage = "tool_message"
    case toolUse = "tool_use"
    case toolResult = "tool_result"
    case image
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
