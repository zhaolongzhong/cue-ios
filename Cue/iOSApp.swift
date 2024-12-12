import CueApp
import SwiftUI

#if os(iOS)
import AVFoundation

@main
struct iOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var dependencies = AppDependencies()
    @StateObject private var appCoordinator = AppCoordinator()

    init() {
        setupAudioSession()
    }

    var body: some Scene {
        WindowGroup {
            AuthenticatedView()
                .environmentObject(dependencies)
                .environmentObject(appCoordinator)
                // .environmentObject(dependencies.conversationManager)
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
#endif
