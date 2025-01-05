import SwiftUI

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
    @Published public var showLiveChat = false

    public init() {}

    func showSettingsSheet() {
        showSettings = true
    }

    func showLiveChatSheet() {
        showLiveChat = true
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

    public func body(content: Content) -> some View {
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

extension View {
    public func withCoordinatorAlert() -> some View {
        modifier(CoordinatorAlertModifier())
    }
}
