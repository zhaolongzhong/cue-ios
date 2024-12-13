import SwiftUI

#if os(iOS)
import UIKit

// MARK: - Haptic Manager
@MainActor
final class HapticManager: @unchecked Sendable {
    static let shared = HapticManager()

    private init() {}

    func shouldPlayHaptics() -> Bool {
        UserDefaults.standard.bool(forKey: "hapticFeedbackEnabled")
    }

    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        Task { @MainActor in
            guard shouldPlayHaptics() else { return }
            let generator = UIImpactFeedbackGenerator(style: style)
            generator.prepare()
            generator.impactOccurred()
        }
    }

    func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        Task { @MainActor in
            guard shouldPlayHaptics() else { return }
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(type)
        }
    }

    func selection() {
        Task { @MainActor in
            guard shouldPlayHaptics() else { return }
            let generator = UISelectionFeedbackGenerator()
            generator.prepare()
            generator.selectionChanged()
        }
    }
}
#endif
