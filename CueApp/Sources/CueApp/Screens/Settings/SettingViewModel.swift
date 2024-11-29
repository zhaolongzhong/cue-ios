import SwiftUI
import Combine

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var currentUser: User?
    private let authService: AuthService
    private var cancellables = Set<AnyCancellable>()

    init(authService: AuthService) {
        self.authService = authService
        self.currentUser = authService.currentUser
        // Subscribe to authService.currentUser changes
        authService.$currentUser
            .assign(to: \.currentUser, on: self)
            .store(in: &cancellables)
    }

    func logout() async {
        await authService.logout()
    }
}
