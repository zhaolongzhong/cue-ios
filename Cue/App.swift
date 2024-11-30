import SwiftUI
import CueApp

#if os(iOS)
import AVFoundation

@main
struct iOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @StateObject private var authService = AuthService()
    @StateObject private var conversationManager = ConversationManager()
    @StateObject private var webSocketStore = WebSocketManagerStore()

    init() {
        setupAudioSession()
    }

    var body: some Scene {
        WindowGroup {
            AuthenticatedView()
                .environmentObject(authService)
                .environmentObject(conversationManager)
                .environmentObject(webSocketStore)
        }
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
}

#else
@main
struct macOSApp: App {
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) var appDelegate
    @StateObject private var authService = AuthService()
    @StateObject private var conversationManager = ConversationManager()
    @StateObject private var webSocketStore = WebSocketManagerStore()

    var body: some Scene {
        WindowGroup {
            AuthenticatedView()
                .environmentObject(authService)
                .environmentObject(conversationManager)
                .environmentObject(webSocketStore)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .commands {
            SidebarCommands()
            ToolbarCommands()
        }

        WindowGroup(id: "settings-window") {
            SettingsView()
                .environmentObject(authService)
                .frame(minWidth: 500, minHeight: 300)
        }
        .defaultSize(width: 600, height: 400)
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
    }
}
#endif
