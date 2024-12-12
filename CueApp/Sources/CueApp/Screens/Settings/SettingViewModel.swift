import SwiftUI
import Combine

@MainActor
public class SettingsViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var generatedToken: String?
    @Published var tokenError: String?
    @Published var isGeneratingToken = false
    var marketingVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var buildVersion: String {
        Bundle.main.infoDictionary?["BUILD_VERSION"] as? String ?? "1"
    }

    private let authService: AuthService
    private var cancellables = Set<AnyCancellable>()

    init(authService: AuthService) {
        self.authService = authService
        self.authService.$currentUser
            .assign(to: \.currentUser, on: self)
            .store(in: &cancellables)

        Task {
            await authService.fetchUserProfile()
        }
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
}
