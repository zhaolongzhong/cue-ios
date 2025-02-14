import SwiftUI
import Dependencies

struct SettingsMenu: View {
    @Dependency(\.featureFlagsViewModel) private var featureFlags
    @EnvironmentObject var apiKeysProviderViewModel: APIKeysProviderViewModel
    let currentUser: User?
    let onOpenAIChat: () -> Void
    let onAnthropicChat: () -> Void
    let onOpenGemini: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        Menu {
            if !apiKeysProviderViewModel.openAIKey.isEmpty && featureFlags.enableOpenAIChat {
                Button(action: onOpenAIChat) {
                    Text("OpenAI")
                        .frame(minWidth: 200, alignment: .leading)
                }

                Divider()
            }

            if !apiKeysProviderViewModel.anthropicKey.isEmpty && featureFlags.enableAnthropicChat {
                Button(action: onAnthropicChat) {
                    Text("Anthropic")
                        .frame(minWidth: 200, alignment: .leading)
                }

                Divider()
            }

            if !apiKeysProviderViewModel.geminiKey.isEmpty && featureFlags.enableGeminiChat {
                Button(action: onOpenGemini) {
                    Text("Gemini")
                        .frame(minWidth: 200, alignment: .leading)
                }
                Divider()
            }

            Button(action: onOpenSettings) {
                Text("Settings")
                    .frame(minWidth: 200, alignment: .leading)
            }
        } label: {
            HStack(alignment: .center) {
                if let user = currentUser {
                    Text(user.displayName)
                } else {
                    Text("Settings")
                }
            }
            .frame(maxHeight: 32)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(maxHeight: 32)
    }
}
