import SwiftUI
import Combine

@MainActor
class SignUpViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var inviteCode = ""
    @Published var error: String?
    @Published var isLoading = false
    private let authService: AuthService

    init(authService: AuthService) {
        self.authService = authService
    }

    @MainActor
    func signUp() async {
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
        error = nil

        do {
            _ = try await authService.signup(
                email: email,
                password: password,
                inviteCode: inviteCode.isEmpty ? nil : inviteCode
            )
        } catch AuthError.emailAlreadyExists {
            self.error = "Email already exists"
        } catch {
            self.error = "An error occurred. Please try again."
        }

        isLoading = false
    }
}

extension ViewModelFactory {
    func makeSignUpViewModel() -> SignUpViewModel {
        SignUpViewModel(authService: dependencies.authService)
    }
}
