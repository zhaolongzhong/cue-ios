import SwiftUI

struct CircularButton: View {
    let systemImage: String
    let action: () -> Void
    let backgroundColor: Color
    let foregroundColor: Color
    let fontSize: CGFloat
    let size: CGFloat

    init(
        systemImage: String,
        backgroundColor: Color = .secondary,
        foregroundColor: Color = .primary,
        fontSize: CGFloat = 12,
        size: CGFloat = 24,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.fontSize = fontSize
        self.size = size
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(backgroundColor)
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primary)
                        .colorInvert()
                )
        }
        .buttonStyle(.plain)
    }
}
