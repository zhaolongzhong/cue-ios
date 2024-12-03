import SwiftUI

struct UserAvatarMenu: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @Environment(\.openWindow) private var openWindow

    var userInitials: String {
        guard let email = dependencies.authService.currentUser?.email else { return "?" }
        return String(email.prefix(2).uppercased())
    }

    var body: some View {
        Button {
            #if os(macOS)
            openWindow(id: "settings-window")
            #else
            // TODO: Handle iOS settings navigation
            #endif
        } label: {
            AvatarView(initials: userInitials)
        }
        .buttonStyle(.plain)
        .help("Settings")
    }
}

private struct AvatarView: View {
    let initials: String

    var body: some View {
        Circle()
            .fill(AppTheme.Colors.lightGray)
            .overlay(
                Text(initials)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
            )
            .frame(width: 32, height: 32)
    }
}

#Preview {
    UserAvatarMenu()
        .environmentObject(AuthService())
}
