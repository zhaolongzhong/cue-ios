import Foundation

struct APIKey: Codable, Equatable, Identifiable, Hashable {
    let id: String
    let name: String
    let secret: String
    let scopes: [String]
    let createdAt: Date
    let expiresAt: Date?
    let lastUsedAt: Date?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case secret
        case scopes
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case lastUsedAt = "last_used_at"
        case isActive = "is_active"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        secret = try container.decode(String.self, forKey: .secret)
        scopes = try container.decode([String].self, forKey: .scopes)
        isActive = try container.decode(Bool.self, forKey: .isActive)

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let createdAtString = try container.decode(String.self, forKey: .createdAt)
        if let date = dateFormatter.date(from: createdAtString) {
            createdAt = date
        } else {
            throw DecodingError.dataCorruptedError(forKey: .createdAt, in: container, debugDescription: "Date string does not match format")
        }

        expiresAt = try container.decodeIfPresent(String.self, forKey: .expiresAt)
                .flatMap { dateFormatter.date(from: $0) }

        lastUsedAt = try container.decodeIfPresent(String.self, forKey: .lastUsedAt)
                .flatMap { dateFormatter.date(from: $0) }
    }
}

struct APIKeyPrivate: Codable, Equatable, Identifiable, Hashable {
    let id: String
    let name: String
    let secret: String
    let userId: String
    let scopes: [String]
    let createdAt: Date
    let expiresAt: Date?
    let lastUsedAt: Date?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case secret
        case userId = "user_id"
        case scopes
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case lastUsedAt = "last_used_at"
        case isActive = "is_active"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        secret = try container.decode(String.self, forKey: .secret)
        scopes = try container.decode([String].self, forKey: .scopes)
        userId = try container.decode(String.self, forKey: .userId)
        isActive = try container.decode(Bool.self, forKey: .isActive)

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let createdAtString = try container.decode(String.self, forKey: .createdAt)
        if let date = dateFormatter.date(from: createdAtString) {
            createdAt = date
        } else {
            throw DecodingError.dataCorruptedError(forKey: .createdAt, in: container, debugDescription: "Date string does not match format")
        }

        expiresAt = try container.decodeIfPresent(String.self, forKey: .expiresAt)
                .flatMap { dateFormatter.date(from: $0) }

        lastUsedAt = try container.decodeIfPresent(String.self, forKey: .lastUsedAt)
                .flatMap { dateFormatter.date(from: $0) }
    }
}

extension APIKey {
    init(id: String,
         name: String,
         secret: String,
         scopes: [String],
         createdAt: Date,
         expiresAt: Date?,
         lastUsedAt: Date?,
         isActive: Bool) {
        self.id = id
        self.name = name
        self.secret = secret
        self.scopes = scopes
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.lastUsedAt = lastUsedAt
        self.isActive = isActive
    }
}

extension APIKeyPrivate {
    func toPublicKey() -> APIKey {
        return APIKey(
            id: self.id,
            name: self.name,
            secret: self.secret,
            scopes: self.scopes,
            createdAt: self.createdAt,
            expiresAt: self.expiresAt,
            lastUsedAt: self.lastUsedAt,
            isActive: self.isActive
        )
    }
}
