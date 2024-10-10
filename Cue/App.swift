import SwiftUI
import CueApp
import AVFoundation

@main
struct MainApp: App {
    init() {
        setupAudioSession()
    }

    var body: some Scene {
        WindowGroup {
            CueAppView()
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
