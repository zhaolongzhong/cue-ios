import SwiftUI

struct CustomTextFieldModifier: ViewModifier {
    let cornerRadius: CGFloat
    let padding: CGFloat
    let backgroundColor: Color
    let strokeColor: Color

    init(
        cornerRadius: CGFloat = 8,
        padding: CGFloat = 8,
        backgroundColor: Color = .secondary.opacity(0.05),
        strokeColor: Color = .secondary.opacity(0.2)
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.backgroundColor = backgroundColor
        self.strokeColor = strokeColor
    }

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .padding(.all, padding)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(strokeColor))
    }
}

extension View {
    func customTextFieldStyle(
        cornerRadius: CGFloat = 8,
        padding: CGFloat = 8,
        backgroundColor: Color = .secondary.opacity(0.05),
        strokeColor: Color = .secondary.opacity(0.2)
    ) -> some View {
        modifier(CustomTextFieldModifier(
            cornerRadius: cornerRadius,
            padding: padding,
            backgroundColor: backgroundColor,
            strokeColor: strokeColor
        ))
    }
}
