import SwiftUI

enum DetailViewType {
    case home
    case assistant(Assistant?)
    case chat
    case email
}

@MainActor
final class HomeNavigationManager: ObservableObject {
    @Published var currentView: DetailViewType = .home
    @Published private(set) var selectedAssistant: Assistant?
    private let userDefaults: UserDefaults
    @Published var isEmailViewPresented = false

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func selectDetailContent(_ detailType: DetailViewType) {
        switch detailType {
        case .home:
            userDefaults.lastSelectedAssistantId = nil
            selectedAssistant = nil
            currentView = .home
        case .assistant(let assistant):
            selectedAssistant = assistant
            userDefaults.lastSelectedAssistantId = assistant?.id ?? nil
            currentView = .assistant(assistant)
        case .email:
            currentView = .email
            isEmailViewPresented = true
        case .chat:
            currentView = .chat
        }
    }
}

// MARK: - UserDefaults Extension
extension UserDefaults {
    private enum Keys {
        static let lastSelectedAssistantId = "lastSelectedAssistantId"
    }

    var lastSelectedAssistantId: String? {
        get { string(forKey: Keys.lastSelectedAssistantId) }
        set { set(newValue, forKey: Keys.lastSelectedAssistantId) }
    }
}
