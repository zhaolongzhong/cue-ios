import SwiftUI
import Combine
import Dependencies

@MainActor
public final class SettingsViewModel: ObservableObject {
    @Dependency(\.apiKeyRepository) private var apiKeyRepository
    @Dependency(\.authRepository) private var authRepository
    @Dependency(\.settingsRepository) private var settingsRepository
    @Published private(set) var currentUser: User?
    @Published private(set) var appConfig: AppConfig?
    @Published private(set) var tokenError: String?
    @Published private(set) var error: String?

    private var cancellables = Set<AnyCancellable>()

    init() {
        refreshAppConfig()
    }

    func refreshUserProfile() {
        Task {
            switch await authRepository.fetchUserProfile() {
            case .success(let user):
                self.currentUser = user
                self.error = nil

            case .failure(.unauthorized):
                self.error = "Please log in to continue"

            case .failure(.networkError):
                self.error = "Network error occurred. Please try again."

            case .failure:
                self.error = "An unexpected error occurred"
                AppLog.log.error("Failed to fetch user profile")
            }
        }
    }

    private func refreshAppConfig() {
        Task {
            let result = await settingsRepository.fetchAppConfig()
            switch result {
            case .success(let config):
                self.appConfig = config
                self.error = nil
            case .failure(let err):
                self.error = err.localizedDescription
            }
        }
    }

    func logout() async {
        await authRepository.logout()
    }

    func getVersionInfo() -> String {
        guard let marketing = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
              let build = Bundle.main.infoDictionary?["BUILD_VERSION"] as? String
        else {
            AppLog.log.error("Failed to load version info")
            return "1.0.0 (1)"
        }
        return "\(marketing)(\(build))"
    }

    public func clearError() {
        error = nil
        tokenError = nil
    }
}
