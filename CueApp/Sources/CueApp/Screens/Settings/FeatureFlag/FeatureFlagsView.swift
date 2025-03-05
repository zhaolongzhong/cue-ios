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
        CenteredScrollView {
            VStack(alignment: .leading, spacing: 24) {
                providersSection
                featuresSection
            }
            .padding()
        }
        .defaultNavigationBar(title: "Feature Flags")
    }

    private var providersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            FeatureFlagSectionHeader(title: "Providers")

            GroupBox {
                VStack(spacing: 0) {
                    FeatureFlagToggleRow(
                        title: "Enable Providers",
                        description: "Master toggle for all providers",
                        isOn: $featureFlags.enableProviders
                    )

                    Divider().padding(.vertical, 8)

                    FeatureFlagToggleRow(
                        title: "Cue Provider",
                        description: "Enable the Cue API provider",
                        isOn: $featureFlags.enableCue
                    )

                    Divider().padding(.vertical, 8)

                    FeatureFlagToggleRow(
                        title: "OpenAI Provider",
                        description: "Enable the OpenAI API provider",
                        isOn: $featureFlags.enableOpenAI
                    )

                    Divider().padding(.vertical, 8)

                    FeatureFlagToggleRow(
                        title: "Anthropic Provider",
                        description: "Enable the Anthropic API provider",
                        isOn: $featureFlags.enableAnthropic
                    )

                    Divider().padding(.vertical, 8)

                    FeatureFlagToggleRow(
                        title: "Gemini Provider",
                        description: "Enable the Gemini API provider",
                        isOn: $featureFlags.enableGemini
                    )

                    Divider().padding(.vertical, 8)

                    FeatureFlagToggleRow(
                        title: "Ollama Provider",
                        description: "Enable the local Ollama provider",
                        isOn: $featureFlags.enableLocal
                    )
                }
                .padding(4)
            }
        }
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            FeatureFlagSectionHeader(title: "Features")

            GroupBox {
                VStack(spacing: 0) {
                    FeatureFlagToggleRow(
                        title: "Media Options",
                        description: "Enable media upload and sharing features",
                        isOn: $featureFlags.enableMediaOptions
                    )

                    Divider().padding(.vertical, 8)

                    FeatureFlagToggleRow(
                        title: "Assistants",
                        description: "Enable custom assistants feature",
                        isOn: $featureFlags.enableAssistants
                    )
                    FeatureFlagToggleRow(
                        title: "Email",
                        description: "Enable email management",
                        isOn: $featureFlags.enableEmail
                    )
                    FeatureFlagToggleRow(
                        title: "Tab View",
                        description: "Enable tab view",
                        isOn: $featureFlags.enableTabView
                    )
                }
                .padding(4)
            }
        }
    }
}

struct FeatureFlagSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .fontWeight(.medium)
            .foregroundColor(.almostPrimary)
    }
}

struct FeatureFlagToggleRow: View {
    let title: String
    let description: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title)
                    .font(.body)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
    }
}
