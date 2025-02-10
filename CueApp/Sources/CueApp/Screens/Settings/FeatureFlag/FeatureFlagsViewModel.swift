import SwiftUI
import Dependencies

extension FeatureFlagsViewModel: DependencyKey {
    public static let liveValue = FeatureFlagsViewModel()
}

extension DependencyValues {
    var featureFlagsViewModel: FeatureFlagsViewModel {
        get { self[FeatureFlagsViewModel.self] }
        set { self[FeatureFlagsViewModel.self] = newValue }
    }
}

final class FeatureFlagsViewModel: ObservableObject, @unchecked Sendable {
    @Published var enableThirdPartyProvider: Bool {
        didSet { UserDefaults.standard.set(enableThirdPartyProvider, forKey: "thirdPartyProvider") }
    }

    init() {
        if UserDefaults.standard.object(forKey: "thirdPartyProvider") != nil {
            enableThirdPartyProvider = UserDefaults.standard.bool(forKey: "thirdPartyProvider")
        } else {
            #if DEBUG
            enableThirdPartyProvider = true
            #else
            enableThirdPartyProvider = false
            #endif
        }
    }
}
