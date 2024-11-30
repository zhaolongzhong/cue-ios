import SwiftUI
public struct AuthenticatedView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var webSocketManagerStore: WebSocketManagerStore

    public init() {}

    public var body: some View {
        Group {
            if authService.isAuthenticated {
                AppTabView(webSocketManagerStore: webSocketManagerStore)
            } else {
                LoginView()
            }
        }
        .onAppear {
            authService.checkAuthStatus()
        }
    }
}
