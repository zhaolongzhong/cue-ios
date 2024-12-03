import Foundation

struct User: Codable, Equatable, Identifiable {
    let id: String
    let email: String
    let name: String?

    enum CodingKeys: String, CodingKey {
        case id = "id"
        case email = "email"
        case name = "name"
    }

    init(id: String, email: String, name: String? = nil) {
        self.id = id
        self.email = email
        self.name = name
    }
}
