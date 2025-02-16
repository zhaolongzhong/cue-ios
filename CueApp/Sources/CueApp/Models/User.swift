import Foundation

struct User: Codable, Equatable, Identifiable {
    let id: String
    let email: String
    let name: String?
    let avatarURL: String?

    enum CodingKeys: String, CodingKey {
        case id = "id"
        case email = "email"
        case name = "name"
        case avatarURL = "avatar_url"
    }

    init(id: String, email: String, name: String? = nil, avatarURL: String? = nil) {
        self.id = id
        self.email = email
        self.name = name
        self.avatarURL = avatarURL
    }
}

extension User {
    var displayName: String {
        name ?? email
    }

    var firstName: String {
        if let fullName = name {
            return fullName.split(separator: " ").first.map(String.init) ?? fullName
        }
        return ""
    }

    var avatarURLString: String {
        avatarURL ?? ""
    }
}
