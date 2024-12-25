import Foundation
import Combine
import Dependencies
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
    func generateToken() async -> AuthResult<String>
    func logout() async
    func fetchUserProfile() async -> AuthResult<User>
}

actor AuthRepository: AuthRepositoryProtocol {
    @Dependency(\.authService) private var authService
    private let userDefaults: UserDefaults

    @MainActor private let currentUserSubject = CurrentValueSubject<User?, Never>(nil)
    @MainActor private let isAuthenticatedSubject = CurrentValueSubject<Bool, Never>(false)

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

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        let hasToken = UserDefaults.standard.string(forKey: "ACCESS_TOKEN_KEY")?.isEmpty == false

        Task { @MainActor in
            isAuthenticatedSubject.send(hasToken)
        }
    }

    func getCurrentAuthState() async -> Bool {
        let hasToken = UserDefaults.standard.string(forKey: "ACCESS_TOKEN_KEY")?.isEmpty == false
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
            let tokenResponse = try await authService.login(email: email, password: password)
            userDefaults.set(tokenResponse.accessToken, forKey: "ACCESS_TOKEN_KEY")
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

    func generateToken() async -> AuthResult<String> {
        do {
            let token = try await authService.generateToken()
            return .success(token)
        } catch let error as AuthError {
            return .failure(error)
        } catch {
            return .failure(.tokenGenerationFailed)
        }
    }

    func logout() async {
        await updateAuthState(false)
        await updateUser(nil)
        userDefaults.removeObject(forKey: "ACCESS_TOKEN_KEY")
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
            if case .unauthorized = error {
                await updateAuthState(false)
                await updateUser(nil)
            }
            return .failure(error)
        } catch {
            return .failure(.networkError)
        }
    }
}
