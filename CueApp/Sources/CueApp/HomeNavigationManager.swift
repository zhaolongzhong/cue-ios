import SwiftUI

public enum WindowId: String {
    case settings = "settings-window"
    case providersManagement = "providers-management-window"
    case compainionChatWindow = "companion-chat-window"
    case liveChatWindow = "live-chat-window"

    public static func companionChatWindowId(_ id: String) -> String {
        return "companion-chat-window-\(id)"
    }

    public static func isCompanionChatWindowId(_ id: String) -> Bool {
        return id.contains("companion-chat-window-")
    }

    public static func isLiveChatWindowId(_ id: String) -> Bool {
        return id.contains("live-chat-window")
    }

    public static func fromRawValue(_ rawValue: String) -> WindowId? {
        if rawValue.contains(WindowId.compainionChatWindow.rawValue) {
            return WindowId.compainionChatWindow
        } else if rawValue.contains(WindowId.liveChatWindow.rawValue) {
            return WindowId.liveChatWindow
        }
        return WindowId(rawValue: rawValue)
    }
}

enum HomeDestination: Hashable {
    case home
    case email
    case cue(String? = nil)
    case openai(String? = nil)
    case anthropic(String? = nil)
    case gemini(String? = nil)
    case local(String? = nil)
    case chat(Assistant)
    case providers
}

@MainActor
final class HomeNavigationManager: ObservableObject {
    @Published var currentView: HomeDestination = .home
    @Published private(set) var selectedAssistant: Assistant?
    private let userDefaults: UserDefaults
    @Published var isEmailViewPresented = false
    @Environment(\.openWindow) private var openWindow

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func navigateTo(_ detailType: HomeDestination) {
        switch detailType {
        case .home:
            userDefaults.lastSelectedAssistantId = nil
            selectedAssistant = nil
            currentView = .home
        case .chat(let assistant):
            selectedAssistant = assistant
            userDefaults.lastSelectedAssistantId = assistant.id
            currentView = .chat(assistant)
        case .email:
            currentView = .email
            isEmailViewPresented = true
        case .cue, .anthropic, .gemini, .openai, .local:
            currentView = detailType
        case .providers:
            #if os(macOS)
            openMacOSWindow(WindowId.providersManagement)
            #else
            currentView = .providers
            #endif
        }
    }
    func openMacOSWindow(_ id: WindowId) {
        #if os(macOS)
        openWindow(id: id.rawValue)
        #endif
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
