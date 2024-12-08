import Foundation

struct AssistantMetadata: Codable, Equatable, Hashable {
    let isPrimary: Bool?
    let model: String?
    let instruction: String?
    let description: String?
    let maxTurns: Int?
    let context: JSONValue?
    let tools: [String]?

    enum CodingKeys: String, CodingKey {
        case isPrimary = "is_primary"
        case model
        case instruction
        case description
        case maxTurns = "max_turns"
        case context
        case tools
    }
}

struct AssistantMetadataUpdate: Codable, Sendable {
    let isPrimary: Bool?
    let model: String?
    let instruction: String?
    let description: String?
    let maxTurns: Int?
    let context: JSONValue?
    let tools: [String]?

    enum CodingKeys: String, CodingKey {
        case isPrimary = "is_primary"
        case model
        case instruction
        case description
        case maxTurns = "max_turns"
        case context
        case tools
    }

    // Initialize with all optional parameters
    init(
        isPrimary: Bool? = nil,
        model: String? = nil,
        instruction: String? = nil,
        description: String? = nil,
        maxTurns: Int? = nil,
        context: JSONValue? = nil,
        tools: [String]? = nil
    ) {
        self.isPrimary = isPrimary
        self.model = model
        self.instruction = instruction
        self.description = description
        self.maxTurns = maxTurns
        self.context = context
        self.tools = tools
    }
}

struct Assistant: Codable, Equatable, Identifiable, Hashable {
    let id: String
    let name: String
    let createdAt: Date
    let updatedAt: Date
    let metadata: AssistantMetadata?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case metadata
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)

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

        metadata = try container.decodeIfPresent(AssistantMetadata.self, forKey: .metadata)
    }
}

extension Assistant {
    var isPrimary: Bool {
        return metadata?.isPrimary == true
    }
}

struct AssistantCreate: Codable {
    let name: String
}
