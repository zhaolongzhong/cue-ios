import SwiftUI
import Dependencies

struct SettingsMenu: View {
    @Dependency(\.featureFlagsViewModel) private var featureFlags
    @EnvironmentObject var providersViewModel: ProvidersViewModel
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

    private func handleOpenSettings() {
        #if os(macOS)
        openWindow(id: WindowId.settings.rawValue)
        #endif
    }
}
