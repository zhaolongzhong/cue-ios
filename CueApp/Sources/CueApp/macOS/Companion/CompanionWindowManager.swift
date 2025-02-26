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
    @Published public var activeWindows: [CompanionWindowIdentifier] = []
    private let configStore: WindowConfigurationStore

    public init(configStore: WindowConfigurationStore) {
        self.configStore = configStore
    }

    public func openCompanionWindow(id: String, config: CompanionWindowConfig) -> CompanionWindowIdentifier {
        let windowId = CompanionWindowIdentifier(id)
        configStore.setConfig(config, for: windowId.id)

        // Add to active windows if not present
        if !activeWindows.contains(where: { $0.id == windowId.id }) {
            activeWindows.append(windowId)
        }
        return windowId
    }

    public func closeCompanionWindow(id: String) {
        let windowId = CompanionWindowIdentifier(id)
        configStore.removeConfig(for: windowId.id)
        activeWindows.removeAll { $0.id == windowId.id }
    }
}
