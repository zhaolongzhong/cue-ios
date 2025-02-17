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
