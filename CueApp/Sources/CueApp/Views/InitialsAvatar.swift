import SwiftUI

struct InitialsAvatar: View {
    let text: String
    let size: CGFloat

    private static let colors: [Color] = [
        .blue, .green, .orange, .purple, .pink, .teal
    ]

    private var avatarColor: Color {
        let hash = abs(text.hashValue)
        let index = hash % Self.colors.count
        return Self.colors[index]
    }

    private var avatarLetter: String {
        String(text.prefix(1).uppercased())
    }

    var body: some View {
        Circle()
            .fill(avatarColor.opacity(0.2))
            .overlay(
                Text(avatarLetter)
                    .font(.system(size: size * 0.44, weight: .medium))
                    .foregroundColor(avatarColor)
            )
            .frame(width: size, height: size)
    }
}
