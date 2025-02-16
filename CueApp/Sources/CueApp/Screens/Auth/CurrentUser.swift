import Foundation

extension UserDefaults {
    private enum Keys {
        static let currentUser = "CURRENT_USER_KEY"
    }

    func saveCurrentUser(_ user: User) throws {
        let encoder = JSONEncoder()
        let userData = try encoder.encode(user)
        set(userData, forKey: Keys.currentUser)
    }

    func getCurrentUser() throws -> User? {
        guard let userData = data(forKey: Keys.currentUser) else {
            return nil
        }
        let decoder = JSONDecoder()
        return try decoder.decode(User.self, from: userData)
    }

    func removeCurrentUser() {
        removeObject(forKey: Keys.currentUser)
    }
}
