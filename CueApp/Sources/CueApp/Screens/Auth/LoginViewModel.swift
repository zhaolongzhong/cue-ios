import SwiftUI
import Dependencies

@MainActor
final class LoginViewModel: ObservableObject {
    @Dependency(\.authRepository) var authRepository
    @Published var email = "" {
        didSet {
            clearError()
        }
    }
    @Published var password = "" {
        didSet {
            clearError()
        }
    }
    @Published var error: String?
    @Published var isLoading = false

    func login() async {
        guard !email.isEmpty, !password.isEmpty else {
            error = "Please fill in all fields"
            return
        }

        isLoading = true
        defer { isLoading = false }

        switch await authRepository.login(email: email, password: password) {
        case .success:
            error = nil

        case .failure(.invalidCredentials):
            error = "Invalid email or password"

        case .failure(.networkError):
            error = "Network error occurred. Please try again."

        case .failure(.unauthorized):
            error = "Invalid email or password"

        case .failure:
            error = "An unexpected error occurred. Please try again."
            AppLog.log.error("Login failed with unknown error")
        }
    }

    public func clearError() {
        error = nil
    }
}
