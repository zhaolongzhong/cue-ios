import SwiftUI
import Dependencies

struct FeatureFlagsView: View {
    @Dependency(\.featureFlagsViewModel) private var featureFlagsProvider
    @ObservedObject private var featureFlags: FeatureFlagsViewModel

    init() {
        let flags: FeatureFlagsViewModel = DependencyValues.live.featureFlagsViewModel
        self._featureFlags = ObservedObject(wrappedValue: flags)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Toggle("Enable Provider", isOn: $featureFlags.enableProviders)
                Toggle("Enable Cue Provider", isOn: $featureFlags.enableCue)
                Toggle("Enable OpenAI Provider", isOn: $featureFlags.enableOpenAI)
                Toggle("Enable Anthropic Provider", isOn: $featureFlags.enableAnthropic)
                Toggle("Enable Gemini Provider", isOn: $featureFlags.enableGemini)
                Toggle("Enable Media Option", isOn: $featureFlags.enableMediaOptions)
                Toggle("Enable Assistants", isOn: $featureFlags.enableAssistants)
            }
            .padding()
        }
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 300)
        #endif
        .defaultNavigationBar(title: "Feature Flags")
    }
}
