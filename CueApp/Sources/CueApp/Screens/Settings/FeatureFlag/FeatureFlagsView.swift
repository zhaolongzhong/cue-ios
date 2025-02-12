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
                Toggle("Enable 3rd Party Provider", isOn: $featureFlags.enableThirdPartyProvider)
                Toggle("Enable Cue Chat", isOn: $featureFlags.enableCueChat)
                Toggle("Enable OpenAI Chat", isOn: $featureFlags.enableOpenAIChat)
                Toggle("Enable Anthropic Chat", isOn: $featureFlags.enableAnthropicChat)
                Toggle("Enable Media Option", isOn: $featureFlags.enableMediaOption)
                Toggle("Enable Assistants", isOn: $featureFlags.enableAssistants)
            }
            .padding()
        }
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 300)
        #endif
        .navigationTitle("Feature Flags")
    }
}
