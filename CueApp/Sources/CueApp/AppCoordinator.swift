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

    public init() {}

    func showSettingsSheet() {
        showSettings = true
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
