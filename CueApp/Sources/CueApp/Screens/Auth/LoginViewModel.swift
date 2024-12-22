import SwiftUI
import Dependencies

@MainActor
final class LoginViewModel: ObservableObject {
    @Dependency(\.authService) var authService
    @Published var email = ""
    @Published var password = ""
    @Published var error: String?
    @Published var isLoading = false

    @MainActor
    func login() async {
        guard !email.isEmpty, !password.isEmpty else {
            error = "Please fill in all fields"
            return
        }

        isLoading = true
        do {
            try await authService.login(email: email, password: password)
            self.error = nil
        } catch AuthError.invalidCredentials {
            self.error = "Invalid email or password"
        } catch {
            self.error = "An error occurred. Please try again."
        }

        isLoading = false
    }
}
