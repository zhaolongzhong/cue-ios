import Foundation

enum AppStateTransition {
    case initialize
    case authenticate(User)
    case logout
    case error(AppStateError)
    case clearError
    case setLoading(Bool)
    
    func apply(to state: AppState) -> AppState {
        switch self {
        case .initialize:
            return AppState(isLoading: true, isAuthenticated: false)
            
        case .authenticate(let user):
            return AppState(
                isLoading: false,
                isAuthenticated: true,
                currentUser: user,
                error: nil
            )
            
        case .logout:
            return AppState(
                isLoading: false,
                isAuthenticated: false,
                currentUser: nil,
                error: nil
            )
            
        case .error(let error):
            return AppState(
                isLoading: false,
                isAuthenticated: state.isAuthenticated,
                currentUser: state.currentUser,
                error: error.errorDescription
            )
            
        case .clearError:
            return AppState(
                isLoading: state.isLoading,
                isAuthenticated: state.isAuthenticated,
                currentUser: state.currentUser,
                error: nil
            )
            
        case .setLoading(let isLoading):
            return AppState(
                isLoading: isLoading,
                isAuthenticated: state.isAuthenticated,
                currentUser: state.currentUser,
                error: state.error
            )
        }
    }
}