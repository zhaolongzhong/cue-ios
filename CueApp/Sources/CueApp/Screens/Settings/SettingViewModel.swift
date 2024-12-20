import SwiftUI
import Combine

@MainActor
public final class SettingsViewModel: ObservableObject {
    @Published private(set) var currentUser: User?
    @Published private(set) var generatedToken: String?
    @Published private(set) var tokenError: String?
    @Published private(set) var isGeneratingToken = false
    @Published private(set) var userError: String?

    private let authService: AuthService
    private var cancellables = Set<AnyCancellable>()

    init(authService: AuthService) {
        self.authService = authService
        setupSubscription()
        refreshUserProfile()
    }

    private func setupSubscription() {
        self.authService.$currentUser
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { completion in
                if case let .failure(error) = completion {
                    AppLog.log.error("Failed to fetch user profile: \(error)")
                }
            }, receiveValue: {[weak self] user in
                self?.currentUser = user
            })
            .store(in: &cancellables)
    }

    private func refreshUserProfile() {
        Task {
            do {
                _ = try await authService.fetchUserProfile()
                userError = nil
            } catch AuthError.unauthorized {
                userError = "Please log in to continue"
            } catch {
                AppLog.log.error("Failed to fetch user profile: \(error.localizedDescription)")
                userError = error.localizedDescription
            }
        }
    }

    func getVersionInfo() -> String {
        guard let marketing = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
              let build = Bundle.main.infoDictionary?["BUILD_VERSION"] as? String
        else {
            AppLog.log.error("Failed to load error info")
            return "1.0.0 (1)"
        }
        return "\(marketing)(\(build))"
    }

    func logout() async {
        await authService.logout()
    }

    func generateToken() async {
        isGeneratingToken = true
        tokenError = nil
        generatedToken = nil

        do {
            let token = try await authService.generateToken()
            generatedToken = token
        } catch {
            tokenError = error.localizedDescription
        }
        isGeneratingToken = false
    }

    public func clearError() {
        userError = nil
        tokenError = nil
    }
}
