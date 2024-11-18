import SwiftUI
public struct AuthenticatedView: View {
    @EnvironmentObject private var authService: AuthService

    public init() {}

    public var body: some View {
        Group {
            if authService.isAuthenticated {
                AppTabView()
            } else {
                LoginView()
            }
        }
        .onAppear {
            authService.checkAuthStatus()
        }
    }
}
