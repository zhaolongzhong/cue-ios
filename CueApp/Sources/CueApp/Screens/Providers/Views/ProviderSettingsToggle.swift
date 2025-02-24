import SwiftUI

struct ProviderSettingsToggle: View {
    let provider: Provider
    let title: String
    let description: String?
    @Binding var isOn: Bool
    let settingsKey: (Provider) -> String

    init(
        provider: Provider,
        title: String,
        description: String? = nil,
        isOn: Binding<Bool>,
        settingsKey: @escaping (Provider) -> String
    ) {
        self.provider = provider
        self.title = title
        self.description = description
        self._isOn = isOn
        self.settingsKey = settingsKey
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title)
                    .font(.body)
                if let description = description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Toggle(title, isOn: $isOn)
                .scaleEffect(0.8)
                .toggleStyle(.switch)
                .labelsHidden()
                .onChange(of: isOn) { _, newValue in
                    // Save to UserDefaults using the key function
                    UserDefaults.standard.set(newValue, forKey: settingsKey(provider))
                }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
    }
}

struct StreamingToggle: View {
    let provider: Provider
    @Binding var isEnabled: Bool

    var body: some View {
        ProviderSettingsToggle(
            provider: provider,
            title: "Enable Streaming",
            description: "Show responses as they are generated in real-time",
            isOn: $isEnabled,
            settingsKey: { ProviderSettingsKeys.Streaming.key(for: $0) }
        )
    }
}

struct ToolsToggle: View {
    let provider: Provider
    @Binding var isEnabled: Bool

    var body: some View {
        ProviderSettingsToggle(
            provider: provider,
            title: "Enable Tools",
            description: "Allow the model to use tools to help answer your questions or tasks",
            isOn: $isEnabled,
            settingsKey: { ProviderSettingsKeys.ToolEnabled.key(for: $0) }
        )
    }
}
