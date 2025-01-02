import Foundation
import Combine
import Dependencies

@MainActor
public protocol AppStateDelegate: AnyObject {
    func onLogout() async
}

struct AppState: Equatable {
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
        isAuthenticated: true,
        currentUser: nil,
        error: nil
    )

    @Dependency(\.authRepository) private var authRepository
    private var cancellables = Set<AnyCancellable>()
    weak var delegate: AppStateDelegate?

    public init() {
        setupSubscriptions()
        Task {
            await initialize()
        }
    }

    private func initialize() async {
        let isAuthenticated = await authRepository.getCurrentAuthState()
        updateState { state in
            state.isAuthenticated = isAuthenticated
            state.isLoading = false
        }

        if isAuthenticated {
            await fetchUserProfile()
        }
    }

    private func setupSubscriptions() {
        authRepository.isAuthenticatedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated in
                guard let self else { return }
                self.updateState { state in
                    state.isAuthenticated = isAuthenticated
                    state.isLoading = false
                }

                // Fetch user profile if authenticated but no current user
                if isAuthenticated && self.state.currentUser == nil {
                    Task { await self.fetchUserProfile() }
                }

                // Handle logout if not authenticated
                if !isAuthenticated {
                    Task { await self.handleLogout() }
                }
            }
            .store(in: &cancellables)
        authRepository.currentUserPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                self?.updateState { state in
                    state.currentUser = user
                }
            }
            .store(in: &cancellables)
    }

    private func fetchUserProfile() async {
        switch await authRepository.fetchUserProfile() {
        case .success(let user):
            updateState { state in
                state.currentUser = user
                state.error = nil
            }

        case .failure(.unauthorized):
            updateState { state in
                state.error = "Session expired. Please log in again."
            }
            await handleLogout()

        case .failure(.networkError):
            updateState { state in
                state.error = "Network error occurred. Please try again."
            }

        case .failure:
            updateState { state in
                state.error = "An unexpected error occurred."
            }
            AppLog.log.error("Unexpected error fetching user profile")
        }
    }

    public func signOut() async {
        AppLog.log.debug("AppStateViewModel signOut")
        await authRepository.logout()
        await handleLogout()
    }

    private func handleLogout() async {
        updateState { state in
            state.currentUser = nil
            state.error = nil
        }
        await delegate?.onLogout()
    }

    private func updateState(_ mutation: (inout AppState) -> Void) {
        var newState = state
        mutation(&newState)
        state = newState
    }

    public func clearError() {
        updateState { state in
            state.error = nil
        }
    }
}
