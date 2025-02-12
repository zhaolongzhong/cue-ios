import SwiftUI

// MARK: - AssistantSelectionManager
@MainActor
final class AssistantSelectionManager: ObservableObject {
    @Published var currentView: DetailViewType = .home
    @Published private(set) var selectedAssistant: Assistant?
    private let userDefaults: UserDefaults
    @Published var isEmailViewPresented = false

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func selectAssistant(_ assistant: Assistant?) {
        selectedAssistant = assistant
        if let assistant = assistant {
            userDefaults.lastSelectedAssistantId = assistant.id
            currentView = .assistant(assistant)
        } else {
            userDefaults.lastSelectedAssistantId = nil
            currentView = .home
        }
    }

    func restoreSelection(from assistants: [Assistant]) {
        guard assistants.isEmpty == false else {
            return
        }

        if let lastSelectedId = userDefaults.lastSelectedAssistantId,
           let lastSelected = assistants.first(where: { $0.id == lastSelectedId }) {
            selectAssistant(lastSelected)
        } else if let primaryAssistant = assistants.first(where: { $0.isPrimary }) {
            selectAssistant(primaryAssistant)
        } else {
            selectAssistant(assistants.first)
        }
    }

    func showChat() {
        currentView = .chat
    }

    func showEmail() {
        isEmailViewPresented = true
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
