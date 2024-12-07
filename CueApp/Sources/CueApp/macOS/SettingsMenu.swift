import SwiftUI

struct SettingsMenu: View {
    let onOpenAIChat: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        HStack {
            Menu {
                Button(action: onOpenAIChat) {
                    Text("OpenAI Chat")
                        .frame(minWidth: 200, alignment: .leading)
                }

                Button(action: onOpenSettings) {
                    Text("Settings")
                        .frame(minWidth: 200, alignment: .leading)
                }
            } label: {
                Image(systemName: "gearshape")
                    .imageScale(.medium)
                    .scaleEffect(1.5)
                    .foregroundColor(.gray)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .menuStyle(.automatic)
            .menuIndicator(.hidden)
            .frame(minHeight: 48)

            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 64)
        .padding(.leading, 8)
    }
}
