import Foundation
import Dependencies

struct UserClient {
    var currentUser: User?
    var updateUser: (_ name: String) async throws -> User
    var logout: () async throws -> Void
}

extension UserClient: DependencyKey {
    static var liveValue: UserClient {
        @Dependency(\.networkClient) var networkClient
        
        return Self(
            currentUser: nil,
            updateUser: { name in
                let endpoint = UserEndpoint.updateProfile(name: name)
                
                return try await networkClient.request(endpoint, as: User.self)
            },
            logout: {
                let endpoint = UserEndpoint.logout
                
                _ = try await networkClient.request(endpoint)
            }
        )
    }
    
    static var testValue: UserClient {
        Self(
            currentUser: User(id: "test-id", email: "test@example.com", name: "Test User"),
            updateUser: { name in
                User(id: "test-id", email: "test@example.com", name: name)
            },
            logout: {}
        )
    }
}

extension DependencyValues {
    var userClient: UserClient {
        get { self[UserClient.self] }
        set { self[UserClient.self] = newValue }
    }
}