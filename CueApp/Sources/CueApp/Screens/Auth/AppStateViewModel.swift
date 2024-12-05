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

    public init(
        isLoading: Bool = true,
        isAuthenticated: Bool = false,
        currentUser: User? = nil
    ) {
        self.isLoading = isLoading
        self.isAuthenticated = isAuthenticated
        self.currentUser = currentUser
    }
}

@MainActor
public class AppStateViewModel: ObservableObject {
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
                        AppLog.log.debug("AppStateViewModel fetchUserProfile")
                        let user = await authService.fetchUserProfile()
                        self.updateState { state in
                            state.currentUser = user
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

    public func signOut() async {
        AppLog.log.debug("AppStateViewModel signOut")
        await authService.logout()
        await handleLogout()
    }

    private func handleLogout() async {
        updateState { state in
            state.currentUser = nil
        }
        await delegate?.handleLogout()
    }

    private func updateState(_ mutation: (inout AppState) -> Void) {
        var newState = state
        mutation(&newState)
        state = newState
    }
}
