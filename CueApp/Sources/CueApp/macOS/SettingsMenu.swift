import SwiftUI

struct SettingsMenu: View {
    @EnvironmentObject var apiKeysViewModel: APIKeysViewModel
    let onOpenAIChat: () -> Void
    let onAnthropicChat: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        Menu {
            if !apiKeysViewModel.openAIKey.isEmpty {
                Button(action: onOpenAIChat) {
                    Text("OpenAI Chat")
                        .frame(minWidth: 200, alignment: .leading)
                }

                Divider()
            }

            if !apiKeysViewModel.anthropicKey.isEmpty {
                Button(action: onAnthropicChat) {
                    Text("Anthropic Chat")
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
