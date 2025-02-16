import SwiftUI
import Dependencies

struct UserAvatar: View {
    @EnvironmentObject private var dependencies: AppDependencies
    let user: User
    let size: CGFloat

    public init(user: User, size: CGFloat = 32) {
        self.user = user
        self.size = size
    }

    private var userInitials: String {
        String(user.displayName.prefix(2).uppercased())
    }

    var body: some View {
        AvatarView(avatarURL: user.avatarURL, initials: userInitials, size: size)
    }
}

private struct AvatarView: View {
    let avatarURL: String?
    let initials: String
    let size: CGFloat

    @State private var imageLoadError: Bool = false

    var body: some View {
        Group {
            if let urlString = avatarURL,
               !urlString.isEmpty,
               !imageLoadError,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: size, height: size)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: size, height: size)
                            .background(AppTheme.Colors.secondaryBackground)
                            .clipShape(Circle())
                    case .failure:
                        InitialsView(initials: initials, size: size)
                            .onAppear { imageLoadError = true }
                    @unknown default:
                        InitialsView(initials: initials, size: size)
                    }
                }
            } else {
                InitialsView(initials: initials, size: size)
            }
        }
    }
}

private struct InitialsView: View {
    let initials: String
    let size: CGFloat

    public init(initials: String, size: CGFloat = 32) {
        self.initials = initials
        self.size = size
    }

    var body: some View {
        Circle()
            .fill(.secondary.opacity(0.2))
            .overlay(
                Text(initials)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundColor(.primary)
            )
            .frame(width: size, height: size)
    }
}
