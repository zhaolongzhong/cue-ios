import Foundation

struct ConversationCreate: Codable {
    let title: String
}

public struct ConversationMetadata: Codable, Equatable, Sendable {
    let isPrimary: Bool
    let capabilities: [String]?

    public init(isPrimary: Bool, capabilities: [String]? = nil) {
        self.isPrimary = isPrimary
        self.capabilities = capabilities
    }

    enum CodingKeys: String, CodingKey {
        case isPrimary = "is_primary"
        case capabilities
    }
}

public struct ConversationModel: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    let title: String
    let createdAt: Date
    let updatedAt: Date
    let assistantId: String?
    let metadata: ConversationMetadata?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case assistantId = "assistant_id"
        case metadata
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)

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
        assistantId = try container.decode(String.self, forKey: .assistantId)
        metadata = try container.decodeIfPresent(ConversationMetadata.self, forKey: .metadata)
    }
}

extension ConversationModel {
    var isPrimary: Bool {
        metadata?.isPrimary ?? false
    }
}
