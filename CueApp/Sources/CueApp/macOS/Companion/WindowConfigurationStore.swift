import SwiftUI

@MainActor
public class WindowConfigurationStore: ObservableObject {
    @Published private var configurations: [String: CompanionWindowConfig] = [:]

    public init() {}

    public func setConfig(_ config: CompanionWindowConfig, for windowId: String) {
        configurations[windowId] = config
    }

    public func getConfig(for windowId: String) -> CompanionWindowConfig? {
        return configurations[windowId]
    }

    public func removeConfig(for windowId: String) {
        configurations.removeValue(forKey: windowId)
    }
}
