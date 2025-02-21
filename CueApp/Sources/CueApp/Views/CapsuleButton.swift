import SwiftUI

struct CapsuleButton: View {
    let title: String
    let action: () -> Void
    let foregroundColor: Color?
    let backgroundColor: Color?

    public init(
        title: String,
        foregroundColor: Color? = .primary,
        backgroundColor: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.action = action
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(foregroundColor)
                .padding(.horizontal, 18)
                .frame(height: 32)
                .background(
                    Capsule()
                        .fill(backgroundColor ?? Color.gray.opacity(0.15))
                )
        }
        .buttonStyle(.plain)
        .padding(.vertical, 8)
    }
}

struct CapsuleOutlineButton: View {
    let title: String
    let foregroundColor: Color?
    let strokeColor: Color
    let action: () -> Void

    public init(
        title: String,
        foregroundColor: Color? = .primary,
        strokeColor: Color = .secondary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.action = action
        self.foregroundColor = foregroundColor
        self.strokeColor = strokeColor
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(foregroundColor)
                .padding(.horizontal, 18)
                .padding(.vertical, 6)
                .overlay(
                    Capsule()
                        .stroke(strokeColor, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
