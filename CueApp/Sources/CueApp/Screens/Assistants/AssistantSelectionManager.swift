import SwiftUI

// MARK: - AssistantSelectionManager
@MainActor
final class AssistantSelectionManager: ObservableObject {
    @Published private(set) var selectedAssistant: Assistant?
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func selectAssistant(_ assistant: Assistant?) {
        selectedAssistant = assistant
        if let assistant = assistant {
            userDefaults.lastSelectedAssistantId = assistant.id
        } else {
            userDefaults.lastSelectedAssistantId = nil
        }
    }

    func restoreSelection(from assistants: [Assistant]) {
        if let lastSelectedId = userDefaults.lastSelectedAssistantId,
           let lastSelected = assistants.first(where: { $0.id == lastSelectedId }) {
            selectAssistant(lastSelected)
        } else if let primaryAssistant = assistants.first(where: { $0.isPrimary }) {
            selectAssistant(primaryAssistant)
        } else if !assistants.isEmpty {
            selectAssistant(assistants.first)
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
