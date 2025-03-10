import SwiftUI
import Dependencies
import GoogleSignIn

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

    func handleGoogleSignInError(_ error: Error?) {
        if let error = error {
            if error.localizedDescription.lowercased().contains("user canceled") {
                return
            }
            self.error = "Google sign in failed: \(error.localizedDescription)"
        } else {
            self.error = "Google sign in failed: Unknown error"
        }
    }

    func handleGoogleSignIn(_ result: GIDSignInResult) async {
        guard let idToken = result.user.idToken?.tokenString else {
            self.error = "Failed to get ID token"
            return
        }

        guard let email = result.user.profile?.email else {
            self.error = "Failed to get email"
            return
        }
        let fullName = result.user.profile?.name
        let avatarURL = result.user.profile?.imageURL(withDimension: 100)

        isLoading = true
        defer { isLoading = false }

        AppLog.log.debug("email: \(email), fullName: \(fullName ?? "")")

        switch await authRepository.signInWithGoogle(
            idToken: idToken,
            email: email,
            fullName: fullName,
            avatarURL: avatarURL?.absoluteString ?? ""
        ) {
        case .success:
            do {
                _ = try await GmailService.getAccessToken()
            } catch {
                AppLog.log.error("Access token fetch failed: \(error)")
            }
            error = nil
        case .failure(.networkError):
            error = "Network error occurred. Please try again."
        case .failure:
            error = "An unexpected error occurred. Please try again."
            AppLog.log.error("Login failed with unknown error")
        }
    }

    public func clearError() {
        error = nil
    }
}
