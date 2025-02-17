import SwiftUI

struct GradientBorder: ViewModifier {
    let gradient = LinearGradient(
        gradient: Gradient(colors: [
            .cyan.opacity(0.9),
            .blue.opacity(0.9),
            .purple.opacity(0.9),
            .red.opacity(0.9)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    @State private var phase: CGFloat = 0
    @State private var isVisible: Bool
    @State private var opacity: CGFloat = 1
    let duration: TimeInterval

    init(isEnabled: Bool, duration: TimeInterval = 3.0) {
        self._isVisible = State(initialValue: isEnabled)
        self.duration = duration
    }

    func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if isVisible {
                        GeometryReader { _ in
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(gradient, lineWidth: 2)
                                .opacity(opacity)
                        }
                    }
                }
            )
            .onAppear {
                if isVisible {
                    // Start fade out animation 0.5 seconds before the end
                    DispatchQueue.main.asyncAfter(deadline: .now() + (duration - 0.5)) {
                        withAnimation(.easeOut(duration: 0.5)) {
                            opacity = 0
                        }
                    }

                    // Hide the border completely after the full duration
                    DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                        isVisible = false
                    }
                }
            }
    }
}

extension View {
    func gradientBorder(isEnabled: Bool, duration: TimeInterval = 5.0) -> some View {
        modifier(GradientBorder(isEnabled: isEnabled, duration: duration))
    }
}
