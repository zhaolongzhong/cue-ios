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

import SwiftUI
import CueApp
import AppKit

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
        .windowStyle(DefaultWindowStyle()) // Apply Default Window Style
        .windowToolbarStyle(UnifiedWindowToolbarStyle()) // Apply Unified Toolbar Style
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure the main window
        if let window = NSApplication.shared.windows.first {
            window.setContentSize(NSSize(width: 800, height: 600))
            window.center()
            window.title = "My macOS App"
        }
    }
}
#endif
