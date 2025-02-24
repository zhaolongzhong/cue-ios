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

    init() {
        enableProviders = UserDefaults.standard.bool(forKey: Keys.enableProviders.key)
        enableCue = UserDefaults.standard.bool(forKey: Keys.enableCue.key)
        enableOpenAI = UserDefaults.standard.bool(forKey: Keys.enableOpenAI.key)
        enableAnthropic = UserDefaults.standard.bool(forKey: Keys.enableAnthropic.key)
        enableGemini = UserDefaults.standard.bool(forKey: Keys.enableGemini.key)
        enableLocal = UserDefaults.standard.bool(forKey: Keys.enableLocal.key)
        enableMediaOptions = UserDefaults.standard.bool(forKey: Keys.enableMediaOptions.key)
        enableAssistants = UserDefaults.standard.bool(forKey: Keys.enableAssistants.key)
    }
}
