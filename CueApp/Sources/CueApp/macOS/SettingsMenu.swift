import SwiftUI
import Dependencies

struct SettingsMenu: View {
    @Dependency(\.featureFlagsViewModel) private var featureFlags
    @EnvironmentObject var apiKeysProviderViewModel: APIKeysProviderViewModel
    @Environment(\.openWindow) private var openWindow
    let currentUser: User?

    var body: some View {
        ZStack {
            HStack(alignment: .center) {
                if let user = currentUser {
                    UserAvatar(user: user, size: 28)
                    Text(user.displayName)
                } else {
                    Text("Settings")
                }
                Spacer()
            }
            .padding(.vertical, 4)
            .cornerRadius(6)
            Menu {
                if !apiKeysProviderViewModel.openAIKey.isEmpty && featureFlags.enableOpenAIChat {
                    Button(action: handleOpenAIChat) {
                        Text("OpenAI")
                            .frame(minWidth: 200, alignment: .leading)
                    }
                    Divider()
                }
                if !apiKeysProviderViewModel.anthropicKey.isEmpty && featureFlags.enableAnthropicChat {
                    Button(action: handleAnthropicChat) {
                        Text("Anthropic")
                            .frame(minWidth: 200, alignment: .leading)
                    }
                    Divider()
                }
                if !apiKeysProviderViewModel.geminiKey.isEmpty && featureFlags.enableGeminiChat {
                    Button(action: handleGeminiChat) {
                        Text("Gemini")
                            .frame(minWidth: 200, alignment: .leading)
                    }
                    Divider()
                }
                Button(action: handleOpenSettings) {
                    Text("Settings")
                        .frame(minWidth: 200, alignment: .leading)
                }
            } label: {
                Rectangle()
                    .foregroundColor(.clear)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
        }
    }

    private func handleOpenAIChat() {
        #if os(macOS)
        openWindow(id: "openai-chat-window")
        #endif
    }

    private func handleAnthropicChat() {
        #if os(macOS)
        openWindow(id: "anthropic-chat-window")
        #endif
    }

    private func handleGeminiChat() {
        #if os(macOS)
        openWindow(id: "gemini-chat-window")
        #endif
    }

    private func handleOpenSettings() {
        #if os(macOS)
        openWindow(id: "settings-window")
        #endif
    }
}
