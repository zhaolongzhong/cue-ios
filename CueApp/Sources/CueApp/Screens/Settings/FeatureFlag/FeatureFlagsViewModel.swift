import SwiftUI
import Dependencies

extension FeatureFlagsViewModel {
    private enum Keys: String {
        case enableThirdPartyProvider
        case enableCueChat
        case enableOpenAIChat
        case enableAnthropicChat
        case enableGeminiChat
        case enableMediaOptions
        case enableAssistants

        var key: String { rawValue }
    }
}

extension FeatureFlagsViewModel: DependencyKey {
    public static let liveValue: FeatureFlagsViewModel = {
        let viewModel = FeatureFlagsViewModel()
        return viewModel
    }()
}

extension DependencyValues {
    var featureFlagsViewModel: FeatureFlagsViewModel {
        get { self[FeatureFlagsViewModel.self] }
        set { self[FeatureFlagsViewModel.self] = newValue }
    }
}

final class FeatureFlagsViewModel: ObservableObject, @unchecked Sendable {
    @Published var enableThirdPartyProvider: Bool {
        didSet { UserDefaults.standard.set(enableThirdPartyProvider, forKey: Keys.enableThirdPartyProvider.key) }
    }
    @Published var enableCueChat: Bool {
        didSet { UserDefaults.standard.set(enableCueChat, forKey: Keys.enableCueChat.key) }
    }
    @Published var enableOpenAIChat: Bool {
        didSet { UserDefaults.standard.set(enableOpenAIChat, forKey: Keys.enableOpenAIChat.key) }
    }
    @Published var enableAnthropicChat: Bool {
        didSet { UserDefaults.standard.set(enableAnthropicChat, forKey: Keys.enableAnthropicChat.key) }
    }
    @Published var enableGeminiChat: Bool {
        didSet { UserDefaults.standard.set(enableGeminiChat, forKey: Keys.enableGeminiChat.key) }
    }
    @Published var enableMediaOptions: Bool {
        didSet { UserDefaults.standard.set(enableMediaOptions, forKey: Keys.enableMediaOptions.key) }
    }
    @Published var enableAssistants: Bool {
        didSet { UserDefaults.standard.set(enableAssistants, forKey: Keys.enableAssistants.key) }
    }

    init() {
        enableThirdPartyProvider = UserDefaults.standard.bool(forKey: Keys.enableThirdPartyProvider.key)
        enableCueChat = UserDefaults.standard.bool(forKey: Keys.enableCueChat.key)
        enableOpenAIChat = UserDefaults.standard.bool(forKey: Keys.enableOpenAIChat.key)
        enableAnthropicChat = UserDefaults.standard.bool(forKey: Keys.enableAnthropicChat.key)
        enableGeminiChat = UserDefaults.standard.bool(forKey: Keys.enableGeminiChat.key)
        enableMediaOptions = UserDefaults.standard.bool(forKey: Keys.enableMediaOptions.key)
        enableAssistants = UserDefaults.standard.bool(forKey: Keys.enableAssistants.key)
    }
}
