import Foundation
import Dependencies
import os.log

extension AuthService: DependencyKey {
    public static let liveValue = AuthService()
}

extension DependencyValues {
    var authService: AuthService {
        get { self[AuthService.self] }
        set { self[AuthService.self] = newValue }
    }
}

protocol AuthServiceProtocol: Sendable {
    func login(email: String, password: String) async throws -> TokenResponse
    func signup(email: String, password: String, inviteCode: String?) async throws -> User
    func generateToken() async throws -> String
    func fetchUserProfile() async throws -> User
}

final class AuthService: AuthServiceProtocol {
    private let logger = Logger(subsystem: "AuthService", category: "Auth")

    func login(email: String, password: String) async throws -> TokenResponse {
        do {
            return try await NetworkClient.shared.request(
                AuthEndpoint.login(email: email, password: password)
            )
        } catch NetworkError.unauthorized {
            throw AuthError.invalidCredentials
        } catch NetworkError.httpError(let code, _) where code == 409 {
            throw AuthError.emailAlreadyExists
        } catch {
            logger.error("Login error: \(error.localizedDescription)")
            throw AuthError.networkError
        }
    }

    func signup(email: String, password: String, inviteCode: String?) async throws -> User {
        do {
            return try await NetworkClient.shared.request(
                AuthEndpoint.signup(email: email, password: password, inviteCode: inviteCode)
            )
        } catch NetworkError.httpError(let code, _) where code == 409 {
            throw AuthError.emailAlreadyExists
        } catch {
            logger.error("Signup error: \(error.localizedDescription)")
            throw AuthError.networkError
        }
    }

    func generateToken() async throws -> String {
        do {
            let response: TokenResponse = try await NetworkClient.shared.request(AssistantEndpoint.generateToken)
            return response.accessToken
        } catch {
            logger.error("Token generation error: \(error.localizedDescription)")
            throw AuthError.tokenGenerationFailed
        }
    }

    func fetchUserProfile() async throws -> User {
        do {
            return try await NetworkClient.shared.request(AuthEndpoint.me)
        } catch NetworkError.unauthorized {
            throw AuthError.unauthorized
        } catch {
            logger.error("Fetch user profile error: \(error.localizedDescription)")
            throw AuthError.networkError
        }
    }
}

struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}
