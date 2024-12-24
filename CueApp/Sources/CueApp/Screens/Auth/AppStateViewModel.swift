import Combine
import Dependencies

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
    @Published private(set) var state: AppState = AppState(
        isLoading: true,
        isAuthenticated: false,
        currentUser: nil,
        error: nil
    )

    @Dependency(\.authService) var authService
    private var cancellables = Set<AnyCancellable>()
    weak var delegate: AppStateDelegate?

    public init() {
        setupAuthSubscription()

        Task {
            await initializeState()
        }
    }

    private func initializeState() async {
        // Fetch the current authentication status without accessing the property wrapper directly in init
        let isAuthenticated = authService.isAuthenticated
        await MainActor.run {
            self.state.isAuthenticated = isAuthenticated
            self.state.isLoading = false
        }

        // If authenticated, fetch the user profile
        if isAuthenticated && self.state.currentUser == nil {
            await fetchUserProfile()
        }
    }

    private func fetchUserProfile() async {
        do {
            let user = try await authService.fetchUserProfile()
            updateState { state in
                state.currentUser = user
                state.error = nil
            }
        } catch AuthError.unauthorized {
            updateState { state in
                state.error = "Session expired. Please log in again."
            }
            await handleLogout()
        } catch AuthError.networkError {
            updateState { state in
                state.error = "Network error occurred. Please try again."
            }
        } catch {
            updateState { state in
                state.error = "An unexpected error occurred."
            }
            AppLog.log.error("Unexpected error: \(error.localizedDescription)")
        }
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
                        await self.fetchUserProfile()
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
