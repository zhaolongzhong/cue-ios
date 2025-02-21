import SwiftUI

struct InitialsAvatar: View {
    let text: String
    let size: CGFloat

    private static let colors: [Color] = [
        .blue, .red, .purple, .cyan
    ]

    private var avatarColor: Color {
        var hash: UInt64 = 5381
        let text = text.lowercased() // Normalize the input

        // djb2 hash algorithm
        for char in text.unicodeScalars {
            hash = ((hash << 5) &+ hash) &+ UInt64(char.value)
        }

        // Use golden ratio to help spread the hash values more evenly
        let phi: Double = 0.618033988749895
        let normalizedHash = Double(hash) * phi
        let fractionalPart = normalizedHash.truncatingRemainder(dividingBy: 1.0)

        let index = Int(floor(fractionalPart * Double(Self.colors.count)))
        return Self.colors[index]
    }

    private var avatarLetter: String {
        if text.isEmpty {
            return "?"
        }
        return String(text.prefix(1).uppercased())
    }

    private var backgroundColor: Color {
        avatarColor.opacity(0.2)
    }

    var body: some View {
        Circle()
            .fill(backgroundColor)
            .overlay(
                Text(avatarLetter)
                    .font(.system(size: size * 0.44, weight: .medium))
                    .foregroundColor(avatarColor)
            )
            .frame(width: size, height: size)
    }
}
