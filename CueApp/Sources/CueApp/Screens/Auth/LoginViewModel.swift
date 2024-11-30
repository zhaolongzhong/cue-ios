import SwiftUI

class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var error: String?
    @Published var isLoading = false

    @MainActor
    func login(authService: AuthService) async {
        guard !email.isEmpty, !password.isEmpty else {
            error = "Please fill in all fields"
            return
        }

        isLoading = true
        do {
            _ = try await authService.login(email: email, password: password)
            self.error = nil // Clear error on successful login
        } catch AuthError.invalidCredentials {
            self.error = "Invalid email or password"
        } catch {
            self.error = "An error occurred. Please try again."
        }

        isLoading = false
    }
}
