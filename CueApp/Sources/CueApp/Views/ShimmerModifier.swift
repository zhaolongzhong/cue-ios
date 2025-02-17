import SwiftUI

struct ShimmerModifier: ViewModifier {
    @State private var progress: CGFloat = -0.4  // Start further left
    var peakOpacity: Double = 0.3

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { _ in
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .white.opacity(0.05), location: 0.2),  // Softer start
                            .init(color: .white.opacity(peakOpacity), location: 0.4),   // Peak opacity
                            .init(color: .white.opacity(0.05), location: 0.6),  // Softer end
                            .init(color: .clear, location: 0.8)                 // Earlier clear
                        ],
                        startPoint: UnitPoint(x: progress, y: 0),
                        endPoint: UnitPoint(x: progress + 1.0, y: 0)  // Wider gradient
                    )
                    .blur(radius: 3)  // Add slight blur for smoother effect
                    .cornerRadius(8)
                }
            )
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)  // Slightly slower animation
                    .repeatForever(autoreverses: false)
                ) {
                    progress = 1.4  // Move further right
                }
            }
            .clipped()
    }
}

public extension View {
    func shimmer(peakOpacity: Double = 0.3) -> some View {
        modifier(ShimmerModifier(peakOpacity: peakOpacity))
    }
}
