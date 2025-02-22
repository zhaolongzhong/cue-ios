import Foundation
import SwiftUI

public struct CompanionWindowIdentifier: Identifiable, Hashable {
    public let id: String

    public init(_ baseId: String) {
        self.id = WindowId.companionChatWindowId(baseId)
    }
}

@MainActor
public class CompanionWindowManager: ObservableObject {
    @Environment(\.openWindow) private var openWindow
    @Published public var activeWindows: [CompanionWindowIdentifier] = []
    private let configStore: WindowConfigurationStore

    public init(configStore: WindowConfigurationStore) {
        self.configStore = configStore
    }

    public func openCompanionWindow(id: String, config: CompanionWindowConfig) {
        let windowId = CompanionWindowIdentifier(id)
        configStore.setConfig(config, for: windowId.id)

        // Add to active windows if not present
        if !activeWindows.contains(where: { $0.id == windowId.id }) {
            activeWindows.append(windowId)
        }
        openWindow(id: WindowId.compainionChatWindow.rawValue, value: windowId.id)
    }

    public func openOpenAILiveChatWindow(id: String) {
        openWindow(id: WindowId.openaiLiveChatWindow.rawValue, value: id)
    }

    public func openGeminiLiveChatWindow(id: String) {
        openWindow(id: WindowId.geminiLiveChatWindow.rawValue, value: id)
    }

    public func closeCompanionWindow(id: String) {
        let windowId = CompanionWindowIdentifier(id)
        configStore.removeConfig(for: windowId.id)
        activeWindows.removeAll { $0.id == windowId.id }
    }
}
