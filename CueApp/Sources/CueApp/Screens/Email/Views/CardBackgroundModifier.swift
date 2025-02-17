import SwiftUI

struct CardStyleModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    let padding: CGFloat
    let showGradientBorder: Bool

    init(padding: CGFloat = 24, showGradientBorder: Bool = false) {
        self.padding = padding
        self.showGradientBorder = showGradientBorder
    }

    func body(content: Content) -> some View {
        content
            .padding(.all, padding)
            #if os(macOS)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(colorScheme == .dark ? AppTheme.Colors.background : .white)
            )
            #else
            .background(colorScheme == .dark ? AppTheme.Colors.secondaryBackground : .white)
            #endif
            .cornerRadius(16)
            .shadow(
                color: colorScheme == .dark ? .white.opacity(0.05) : .black.opacity(0.1),
                radius: 8,
                x: 0,
                y: 2
            )
            .gradientBorder(isEnabled: showGradientBorder)
            .padding()
    }
}

extension View {
    func cardStyle(padding: CGFloat = 24, showGradientBorder: Bool = false) -> some View {
        modifier(CardStyleModifier(padding: padding, showGradientBorder: showGradientBorder))
    }
}
