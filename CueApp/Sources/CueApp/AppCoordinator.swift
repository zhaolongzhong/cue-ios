import SwiftUI

#if os(macOS)
import Sparkle
#endif

@MainActor
public class AppCoordinator: ObservableObject {
    public enum AlertType: Identifiable {
        case error(String)
        case confirmation(title: String, message: String)
        case custom(title: String, message: String, primaryAction: () -> Void)

        public var id: UUID {
            UUID()
        }
    }

    @Published public var activeAlert: AlertType?
    @Published public var showSettings = false
    @Published public var showProviders = false
    @Published public var showLiveChat = false
    @Published public var liveChatConfig = CompanionWindowConfig(provider: .gemini)

    #if os(macOS)
    private let updater: SPUUpdater?
    private let dynamicDelegate: DynamicFeedUpdaterDelegate?

    public init(updater: SPUUpdater? = nil, dynamicDelegate: DynamicFeedUpdaterDelegate? = nil) {
       self.updater = updater
       self.dynamicDelegate = dynamicDelegate
    }

    public func checkForUpdates(withAppcastUrl appcastUrl: String? = nil) {
        if let appcastUrl = appcastUrl {
            dynamicDelegate?.dynamicFeedURL = appcastUrl
        }
        updater?.checkForUpdates()
    }
    #else
    public init () {
    }
    #endif

    func showSettingsSheet() {
        showSettings = true
    }

    func showProvidersSheet() {
        showProviders = true
    }

    func showLiveChatSheet(_ config: CompanionWindowConfig) {
        showLiveChat = true
        self.liveChatConfig = config
    }

    public func showError(_ message: String) {
        activeAlert = .error(message)
    }

    public func showConfirmation(title: String, message: String) {
        activeAlert = .confirmation(title: title, message: message)
    }

    public func showCustomAlert(title: String, message: String, action: @escaping () -> Void) {
        activeAlert = .custom(title: title, message: message, primaryAction: action)
    }
}

@MainActor
public struct CoordinatorAlertModifier: ViewModifier {
    @EnvironmentObject var coordinator: AppCoordinator

    let isCompanion: Bool

    init(isCompanion: Bool = false) {
        self.isCompanion = isCompanion
    }

    public func body(content: Content) -> some View {
        if isCompanion {
            content
        } else {
            content
                .alert(item: $coordinator.activeAlert) { alertType in
                    switch alertType {
                    case .error(let message):
                        Alert(
                            title: Text("Error"),
                            message: Text(message),
                            dismissButton: .default(Text("OK"))
                        )

                    case .confirmation(let title, let message):
                        Alert(
                            title: Text(title),
                            message: Text(message),
                            primaryButton: .default(Text("OK")),
                            secondaryButton: .cancel()
                        )

                    case .custom(let title, let message, let action):
                        Alert(
                            title: Text(title),
                            message: Text(message),
                            primaryButton: .default(Text("OK"), action: action),
                            secondaryButton: .cancel()
                        )
                    }
                }
        }
    }
}

extension View {
    public func withCoordinatorAlert(isCompanion: Bool = false) -> some View {
        modifier(CoordinatorAlertModifier(isCompanion: isCompanion))
    }
}
