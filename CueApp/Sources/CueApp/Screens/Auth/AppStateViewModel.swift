import Combine
import Dependencies
import OSLog

@MainActor
public protocol AppStateDelegate: AnyObject {
    func handleLogout() async
}

/// Immutable state structure representing the application's authentication and user state
public struct AppState: Equatable {
    public let isLoading: Bool
    public let isAuthenticated: Bool
    public let currentUser: User?
    public let error: String?
    
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

/// View model managing application state and authentication
@MainActor
public final class AppStateViewModel: ObservableObject {
    private static let logger = Logger(subsystem: "com.cue.app", category: "AppState")
    
    @Published private(set) var state: AppState
    
    @Dependency(\.authService) private var authService
    private var cancellables = Set<AnyCancellable>()
    weak var delegate: AppStateDelegate?
    
    // MARK: - Initialization
    
    public init(initialState: AppState = AppState()) {
        self.state = initialState
        setupAuthSubscription()
        
        Task {
            await initializeState()
        }
    }
    
    // MARK: - State Management
    
    private func transition(_ transition: AppStateTransition) {
        let oldState = state
        state = transition.apply(to: state)
        
        Self.logger.debug("State transition: \(String(describing: transition))")
        Self.logger.debug("State changed from: \(String(describing: oldState)) to: \(String(describing: state))")
    }
    
    // MARK: - Authentication Flow
    
    private func initializeState() async {
        transition(.setLoading(true))
        
        let isAuthenticated = authService.isAuthenticated
        transition(.setLoading(false))
        
        if isAuthenticated {
            await fetchUserProfile()
        }
    }
    
    private func fetchUserProfile() async {
        transition(.setLoading(true))
        
        do {
            let user = try await authService.fetchUserProfile()
            transition(.authenticate(user))
        } catch AuthError.unauthorized {
            transition(.error(.sessionExpired))
            await handleLogout()
        } catch AuthError.networkError {
            transition(.error(.networkError))
        } catch {
            transition(.error(.profileFetchFailed(error)))
            Self.logger.error("Profile fetch failed: \(error.localizedDescription)")
        }
    }
    
    private func setupAuthSubscription() {
        authService.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] authenticated in
                guard let self = self else { return }
                
                if !authenticated {
                    Task { @MainActor in
                        Self.logger.debug("Auth state changed to unauthenticated")
                        await self.handleLogout()
                    }
                } else if authenticated && self.state.currentUser == nil {
                    Task { @MainActor in
                        Self.logger.debug("Auth state changed to authenticated, fetching profile")
                        await self.fetchUserProfile()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Interface
    
    public func signOut() async {
        Self.logger.debug("User initiated sign out")
        transition(.setLoading(true))
        await authService.logout()
        await handleLogout()
    }
    
    public func clearError() {
        transition(.clearError)
    }
    
    // MARK: - Private Helpers
    
    private func handleLogout() async {
        transition(.logout)
        await delegate?.handleLogout()
    }
    
    // MARK: - State Restoration
    
    public func encodeState() -> Data? {
        try? JSONEncoder().encode(state)
    }
    
    public func restoreState(from data: Data) {
        guard let restoredState = try? JSONDecoder().decode(AppState.self, from: data) else {
            Self.logger.error("Failed to restore state from data")
            return
        }
        state = restoredState
    }
}
