import SwiftUI
import Combine

@MainActor
public protocol AppStateDelegate: AnyObject {
    func handleLogout() async
}

struct AppState {
    var isLoading: Bool
    var isAuthenticated: Bool
    var currentUser: User?
    var error: String?

    public init(
        isLoading: Bool = true,
        isAuthenticated: Bool = false,
        currentUser: User? = nil,
        error: String? = nil
    ) {
        self.isLoading = isLoading
        self.isAuthenticated = isAuthenticated
        self.currentUser = currentUser
        self.error = error
    }
}

@MainActor
public final class AppStateViewModel: ObservableObject {
    @Published private(set) var state: AppState

    private let authService: AuthService
    private var cancellables = Set<AnyCancellable>()
    weak var delegate: AppStateDelegate?

    public init(authService: AuthService) {
        self.authService = authService
        self.state = AppState(
            isLoading: true,
            isAuthenticated: authService.isAuthenticated,
            currentUser: nil
        )
        setupAuthSubscription()
    }

    private func setupAuthSubscription() {
        authService.$isAuthenticated
            .sink { [weak self] authenticated in
                guard let self = self else { return }
                AppLog.log.debug("AppStateViewModel self.state.isAuthenticated: \(self.state.isAuthenticated), authenticated: \(authenticated)")

                self.updateState { state in
                    state.isAuthenticated = authenticated
                    state.isLoading = false
                }

                if authenticated && self.state.currentUser == nil {
                    Task {
                        do {
                            let user = try await authService.fetchUserProfile()
                            self.updateState { state in
                                state.currentUser = user
                                state.error = nil
                            }
                        } catch AuthError.unauthorized {
                            self.updateState { state in
                                state.error = "Session expired. Please log in again."
                            }
                            await self.handleLogout()
                        } catch AuthError.networkError {
                            self.updateState { state in
                                state.error = "Network error occurred. Please try again."
                            }
                        } catch {
                            self.updateState { state in
                                state.error = "An unexpected error occurred."
                            }
                            AppLog.log.error("Unexpected error: \(error.localizedDescription)")
                        }
                    }
                }

                if !authenticated {
                    Task {
                        AppLog.log.debug("AppStateViewModel handleLogout")
                        await self.handleLogout()
                    }
                }
            }
            .store(in: &cancellables)
    }

    private func updateState(_ mutation: (inout AppState) -> Void) {
        var newState = state
        mutation(&newState)
        state = newState
    }

    public func signOut() async {
        AppLog.log.debug("AppStateViewModel signOut")
        await authService.logout()
        await handleLogout()
    }

    private func handleLogout() async {
        updateState { state in
            state.currentUser = nil
            state.error = nil
        }
        await delegate?.handleLogout()
    }

    public func clearError() {
        updateState { state in
            state.error = nil
        }
    }
}
