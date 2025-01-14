import SwiftUI

struct SettingsMenu: View {
    @EnvironmentObject var apiKeysProviderViewModel: APIKeysProviderViewModel
    let onOpenAIChat: () -> Void
    let onAnthropicChat: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        Menu {
            if !apiKeysProviderViewModel.openAIKey.isEmpty {
                Button(action: onOpenAIChat) {
                    Text("OpenAI")
                        .frame(minWidth: 200, alignment: .leading)
                }

                Divider()
            }

            if !apiKeysProviderViewModel.anthropicKey.isEmpty {
                Button(action: onAnthropicChat) {
                    Text("Anthropic")
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
                Text("Settings")
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(maxHeight: 32)
    }
}
