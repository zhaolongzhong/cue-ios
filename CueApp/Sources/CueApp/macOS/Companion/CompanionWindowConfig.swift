import Foundation
import SwiftUI
import CueCommon

public struct CompanionWindowConfig: Codable, Equatable, Hashable {
    let model: String?
    let provider: Provider?
    let assistantId: String?
    let conversationId: String?
    let additionalSettings: [String: String]

    public init(
        model: String? = nil,
        provider: Provider? = nil,
        assistantId: String? = nil,
        conversationId: String? = nil,
        additionalSettings: [String: String] = [:]
    ) {
        self.model = model
        self.provider = provider
        self.assistantId = assistantId
        self.conversationId = conversationId
        self.additionalSettings = additionalSettings
    }
}

private struct CompanionWindowConfigKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue: CompanionWindowConfig? = nil
}

extension EnvironmentValues {
    var companionWindowConfig: CompanionWindowConfig? {
        get { self[CompanionWindowConfigKey.self] }
        set { self[CompanionWindowConfigKey.self] = newValue }
    }
}
