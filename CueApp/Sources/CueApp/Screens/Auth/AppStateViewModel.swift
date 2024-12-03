import SwiftUI
import Combine

@MainActor
public class AppStateViewModel: ObservableObject {
    @Published private(set) var isAuthenticated = false
    @Published private(set) var isLoading = true

    private let authService: AuthService
    private var cancellables = Set<AnyCancellable>()

    init(authService: AuthService) {
        self.authService = authService
        setupAuthSubscription()
    }

    private func setupAuthSubscription() {
        authService.$isAuthenticated
            .sink { [weak self] authenticated in
                self?.isAuthenticated = authenticated
            }
            .store(in: &cancellables)
    }

    func checkAuthStatus() {
        isLoading = true
        Task {
            isAuthenticated = authService.checkAuthStatus()
            isLoading = false
        }
    }

    func signOut() async {
        await authService.logout()
        isAuthenticated = false
    }
}
