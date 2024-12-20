import Foundation
import Combine
import os.log

enum AuthError: LocalizedError {
    case invalidCredentials
    case networkError
    case invalidResponse
    case emailAlreadyExists
    case unauthorized
    case unknown
    case tokenGenerationFailed

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .networkError:
            return "Network error occurred"
        case .invalidResponse:
            return "Invalid response from server"
        case .emailAlreadyExists:
            return "Email already exists"
        case .unauthorized:
            return "Unauthorized access"
        case .tokenGenerationFailed:
            return "Failed to generate access token"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}

@MainActor
public class AuthService: ObservableObject {
    @Published public var isAuthenticated = false
    @Published private(set) var currentUser: User?
    @Published private(set) var isGeneratingToken = false

    private let userDefaults: UserDefaults
    private let logger = Logger(subsystem: "AuthService", category: "Auth")

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.isAuthenticated = getAccessToken()?.isEmpty == false
    }

    func login(email: String, password: String) async throws {
        do {
            let response: TokenResponse = try await NetworkClient.shared.request(
                AuthEndpoint.login(email: email, password: password)
            )

            userDefaults.set(response.accessToken, forKey: "ACCESS_TOKEN_KEY")
            isAuthenticated = true
            _ = try await fetchUserProfile()
        } catch NetworkError.unauthorized {
            throw AuthError.invalidCredentials
        } catch NetworkError.httpError(let code, _) where code == 409 {
            throw AuthError.emailAlreadyExists
        } catch {
            logger.error("Login error: \(error.localizedDescription)")
            throw AuthError.networkError
        }
    }

    func signup(email: String, password: String, inviteCode: String?) async throws {
        do {
            let _: User = try await NetworkClient.shared.request(
                AuthEndpoint.signup(email: email, password: password, inviteCode: inviteCode)
            )
            _ = try await login(email: email, password: password)
        } catch NetworkError.httpError(let code, _) where code == 409 {
            throw AuthError.emailAlreadyExists
        } catch {
            logger.error("Signup error: \(error.localizedDescription)")
            throw AuthError.networkError
        }
    }

    func generateToken() async throws -> String {
        isGeneratingToken = true
        defer { isGeneratingToken = false }

        do {
            let response: TokenResponse = try await NetworkClient.shared.request(AssistantEndpoint.generateToken)
            return response.accessToken
        } catch {
            logger.error("Token generation error: \(error.localizedDescription)")
            throw AuthError.tokenGenerationFailed
        }
    }

    func logout() async {
        AppLog.log.debug("AuthService logout")
        isAuthenticated = false
        userDefaults.removeObject(forKey: "ACCESS_TOKEN_KEY")
        currentUser = nil
    }

    func getAccessToken() -> String? {
        return userDefaults.string(forKey: "ACCESS_TOKEN_KEY")
    }

    func fetchUserProfile() async throws -> User {
        guard isAuthenticated else {
            throw AuthError.unauthorized
        }

        do {
            let user: User = try await NetworkClient.shared.request(AuthEndpoint.me)
            logger.debug("Fetched user profile: \(user.email)")
            currentUser = user
            return user
        } catch NetworkError.unauthorized {
            isAuthenticated = false
            currentUser = nil
            throw AuthError.unauthorized
        } catch {
            logger.error("Fetch user profile error: \(error.localizedDescription)")
            throw AuthError.networkError
        }
    }
}

// MARK: - Response Models
struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}
