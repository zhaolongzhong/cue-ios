import SwiftUI

struct SettingsMenu: View {
    let onOpenAIChat: () -> Void
    let onAnthropicChat: () -> Void
    let onGeminiChat: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        Menu {
            Button(action: onOpenAIChat) {
                Text("OpenAI Chat")
                    .frame(minWidth: 200, alignment: .leading)
            }

            Divider()

            Button(action: onAnthropicChat) {
                Text("Anthropic Chat")
                    .frame(minWidth: 200, alignment: .leading)
            }

            Divider()
            
            Button(action: onGeminiChat) {
                Text("Gemini Chat")
                    .frame(minWidth: 200, alignment: .leading)
            }

            Divider()

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
