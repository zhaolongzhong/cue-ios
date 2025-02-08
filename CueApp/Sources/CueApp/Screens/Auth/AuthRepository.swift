import Foundation
import Combine
import Dependencies
import os.log

enum AuthError: LocalizedError, Equatable {
    case invalidCredentials
    case emailAlreadyExists
    case networkError
    case refreshTokenExpired
    case refreshTokenMissing
    case invalidResponse
    case forbidden(message: String)
    case unauthorized
    case unknown
    case tokenGenerationFailed

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Incorrect email address or password."
        case .emailAlreadyExists:
            return "Email already exists."
        case .networkError:
            return "Network error occurred."
        case .refreshTokenExpired:
            return "Refresh token expired."
        case .refreshTokenMissing:
            return "Refresh token missing."
        case .invalidResponse:
            return "Invalid response from server."
        case .forbidden(let message):
            return "Forbidden: \(message)"
        case .unauthorized:
            return "Unauthorized access."
        case .tokenGenerationFailed:
            return "Failed to generate access token."
        case .unknown:
            return "An unknown error occurred."
        }
    }
}

enum AuthResult<T: Sendable>: Sendable {
    case success(T)
    case failure(AuthError)
}

extension AuthRepository: DependencyKey {
    static let liveValue: AuthRepositoryProtocol = AuthRepository()
}

extension DependencyValues {
    var authRepository: AuthRepositoryProtocol {
        get { self[AuthRepository.self] }
        set { self[AuthRepository.self] = newValue }
    }
}

protocol AuthRepositoryProtocol: Sendable {
    @MainActor var isAuthenticatedPublisher: AnyPublisher<Bool, Never> { get }
    @MainActor var currentUserPublisher: AnyPublisher<User?, Never> { get }
    @MainActor var currentUser: User? { get }

    func getCurrentAuthState() async -> Bool
    func login(email: String, password: String) async -> AuthResult<Void>
    func signup(email: String, password: String, inviteCode: String?) async -> AuthResult<Void>
    func logout() async
    func fetchUserProfile() async -> AuthResult<User>
    func signInWithGoogle(
        idToken: String,
        email: String?,
        fullName: String?,
        givenName: String?,
        familyName: String?
    ) async -> AuthResult<Void>
}

actor AuthRepository: AuthRepositoryProtocol {
    @Dependency(\.authService) private var authService

    @MainActor private let currentUserSubject = CurrentValueSubject<User?, Never>(nil)
    @MainActor private let isAuthenticatedSubject = CurrentValueSubject<Bool, Never>(true)

    @MainActor
    var isAuthenticatedPublisher: AnyPublisher<Bool, Never> {
        isAuthenticatedSubject.eraseToAnyPublisher()
    }

    @MainActor
    var currentUserPublisher: AnyPublisher<User?, Never> {
        currentUserSubject.eraseToAnyPublisher()
    }

    @MainActor
    var currentUser: User? {
        currentUserSubject.value
    }

    private var isAuthenticated: Bool {
        get async {
            await MainActor.run { isAuthenticatedSubject.value }
        }
    }

    init() {
        let hasToken = UserDefaults.standard.string(forKey: "ACCESS_TOKEN_KEY")?.isEmpty == false
        Task { @MainActor in
            isAuthenticatedSubject.send(hasToken)
        }
    }

    func getCurrentAuthState() async -> Bool {
        let hasToken = await TokenManager.shared.accessToken?.isEmpty == false
        await updateAuthState(hasToken)
        return hasToken
    }

    @MainActor
    private func updateAuthState(_ isAuthenticated: Bool) async {
        isAuthenticatedSubject.send(isAuthenticated)
    }

    @MainActor
    private func updateUser(_ user: User?) async {
        currentUserSubject.send(user)
    }

    func login(email: String, password: String) async -> AuthResult<Void> {
        do {
            let response = try await authService.login(email: email, password: password)
            await TokenManager.shared.saveTokens(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken
            )
            await updateAuthState(true)

            switch await fetchUserProfile() {
            case .success(let user):
                await updateUser(user)
                return .success(())
            case .failure(let error):
                return .failure(error)
            }
        } catch let error as AuthError {
            return .failure(error)
        } catch {
            return .failure(.unknown)
        }
    }

    func signup(email: String, password: String, inviteCode: String?) async -> AuthResult<Void> {
        do {
            _ = try await authService.signup(email: email, password: password, inviteCode: inviteCode)
            return await login(email: email, password: password)
        } catch let error as AuthError {
            return .failure(error)
        } catch {
            return .failure(.unknown)
        }
    }

    func logout() async {
        do {
            _ = try await authService.logout()
        } catch {
            AppLog.log.error("Log out error: \(error.localizedDescription)")
        }

        await TokenManager.shared.clearTokens()
        await updateAuthState(false)
        await updateUser(nil)
    }

    func fetchUserProfile() async -> AuthResult<User> {
        guard await isAuthenticated else {
            return .failure(.unauthorized)
        }

        do {
            let user = try await authService.fetchUserProfile()
            await updateUser(user)
            return .success(user)
        } catch let error as AuthError {
            switch error {
            case .unauthorized:
                await updateAuthState(false)
                await updateUser(nil)
            default:
                break
            }
            return .failure(error)
        } catch {
            return .failure(.networkError)
        }
    }

    func signInWithGoogle(
        idToken: String,
        email: String?,
        fullName: String?,
        givenName: String?,
        familyName: String?
    ) async -> AuthResult<Void> {
        do {
            let response = try await authService.signInWithGoogle(
                idToken: idToken,
                email: email,
                fullName: fullName,
                givenName: givenName,
                familyName: familyName
            )
            await TokenManager.shared.saveTokens(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken
            )
            await updateAuthState(true)

            switch await fetchUserProfile() {
            case .success(let user):
                await updateUser(user)
                return .success(())
            case .failure(let error):
                return .failure(error)
            }
        } catch let error as AuthError {
            return .failure(error)
        } catch {
            return .failure(.unknown)
        }
    }
}
