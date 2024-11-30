import SwiftUI
public struct AuthenticatedView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var webSocketManagerStore: WebSocketManagerStore

    public init() {}

    public var body: some View {
        Group {
            if authService.isAuthenticated {
                #if os(iOS)
                AppTabView(webSocketManagerStore: webSocketManagerStore)
                #else
                MainWindowView(webSocketManagerStore: webSocketManagerStore)
                                    .environmentObject(authService)
                #endif
            } else {
                LoginView()
            }
        }
        .onAppear {
            authService.checkAuthStatus()
        }
    }
}
