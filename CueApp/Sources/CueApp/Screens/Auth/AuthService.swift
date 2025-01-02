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

    func logout() async throws -> StatusResponse {
        do {
            return try await NetworkClient.shared.request(
                AuthEndpoint.logout
            )
        } catch {
            throw AuthError.networkError
        }
    }

    func fetchUserProfile() async throws -> User {
        do {
            return try await NetworkClient.shared.request(AuthEndpoint.me)
        } catch NetworkError.unauthorized {
            throw AuthError.unauthorized
        } catch NetworkError.forbidden(let message) {
            throw AuthError.forbidden(message: message)
        } catch {
            logger.error("Fetch user profile error: \(error.localizedDescription)")
            throw AuthError.networkError
        }
    }
}
