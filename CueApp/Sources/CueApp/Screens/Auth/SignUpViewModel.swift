import SwiftUI
import Combine
import Dependencies

@MainActor
final class SignUpViewModel: ObservableObject {
    @Dependency(\.authRepository) var authRepository
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var inviteCode = ""
    @Published var error: String?
    @Published var isLoading = false

    func signup() async {
        guard !email.isEmpty, !password.isEmpty else {
            error = "Please fill in all required fields"
            return
        }

        guard password == confirmPassword else {
            error = "Passwords do not match"
            return
        }

        guard password.count >= 8 else {
            error = "Password must be at least 8 characters"
            return
        }

        isLoading = true
        defer { isLoading = false }

        let inviteCodeToUse = inviteCode.isEmpty ? nil : inviteCode

        switch await authRepository.signup(
            email: email,
            password: password,
            inviteCode: inviteCodeToUse
        ) {
        case .success:
            error = nil

        case .failure(.emailAlreadyExists):
            error = "Email already exists"

        case .failure(.networkError):
            error = "Network error occurred. Please try again."

        case .failure(.invalidCredentials):
            error = "Invalid email or password format"

        case .failure:
            error = "An unexpected error occurred. Please try again."
            AppLog.log.error("Signup failed with unknown error")
        }
    }
}
