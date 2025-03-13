import SwiftUI
import Dependencies

extension FeatureFlagsViewModel {
    private enum Keys: String {
        case enableProviders
        case enableCue
        case enableOpenAI
        case enableAnthropic
        case enableGemini
        case enableLocal
        case enableMediaOptions
        case enableAssistants
        case enableEmail
        case enableTabView
        case enableMCP
        case enableCLIRunner

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
    @Published var enableProviders: Bool {
        didSet { UserDefaults.standard.set(enableProviders, forKey: Keys.enableProviders.key) }
    }
    @Published var enableCue: Bool {
        didSet { UserDefaults.standard.set(enableCue, forKey: Keys.enableCue.key) }
    }
    @Published var enableOpenAI: Bool {
        didSet { UserDefaults.standard.set(enableOpenAI, forKey: Keys.enableOpenAI.key) }
    }
    @Published var enableAnthropic: Bool {
        didSet { UserDefaults.standard.set(enableAnthropic, forKey: Keys.enableAnthropic.key) }
    }
    @Published var enableGemini: Bool {
        didSet { UserDefaults.standard.set(enableGemini, forKey: Keys.enableGemini.key) }
    }
    @Published var enableLocal: Bool {
        didSet { UserDefaults.standard.set(enableGemini, forKey: Keys.enableLocal.key) }
    }
    @Published var enableMediaOptions: Bool {
        didSet { UserDefaults.standard.set(enableMediaOptions, forKey: Keys.enableMediaOptions.key) }
    }
    @Published var enableAssistants: Bool {
        didSet { UserDefaults.standard.set(enableAssistants, forKey: Keys.enableAssistants.key) }
    }
    @Published var enableEmail: Bool {
        didSet { UserDefaults.standard.set(enableEmail, forKey: Keys.enableEmail.key) }
    }
    @Published var enableTabView: Bool {
        didSet { UserDefaults.standard.set(enableTabView, forKey: Keys.enableTabView.key) }
    }
    @Published var enableMCP: Bool {
        didSet { UserDefaults.standard.set(enableMCP, forKey: Keys.enableMCP.key) }
    }
    @Published var enableCLIRunner: Bool {
        didSet { UserDefaults.standard.set(enableCLIRunner, forKey: Keys.enableCLIRunner.key) }
    }

    init() {
        enableProviders = UserDefaults.standard.bool(forKey: Keys.enableProviders.key)
        enableCue = UserDefaults.standard.bool(forKey: Keys.enableCue.key)
        enableOpenAI = UserDefaults.standard.bool(forKey: Keys.enableOpenAI.key)
        enableAnthropic = UserDefaults.standard.bool(forKey: Keys.enableAnthropic.key)
        enableGemini = UserDefaults.standard.bool(forKey: Keys.enableGemini.key)
        enableLocal = UserDefaults.standard.bool(forKey: Keys.enableLocal.key)
        UserDefaults.standard.register(defaults: [Keys.enableMediaOptions.key: true])
        enableMediaOptions = UserDefaults.standard.bool(forKey: Keys.enableMediaOptions.key)
        enableAssistants = UserDefaults.standard.bool(forKey: Keys.enableAssistants.key)
        enableEmail = UserDefaults.standard.bool(forKey: Keys.enableEmail.key)
        enableTabView = UserDefaults.standard.bool(forKey: Keys.enableTabView.key)
        UserDefaults.standard.register(defaults: [Keys.enableMCP.key: true])
        enableMCP = UserDefaults.standard.bool(forKey: Keys.enableMCP.key)
        enableCLIRunner = UserDefaults.standard.bool(forKey: Keys.enableCLIRunner.key)
    }
}
