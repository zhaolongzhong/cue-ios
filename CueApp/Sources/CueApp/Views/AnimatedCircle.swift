import SwiftUI

struct AnimatedCircle: View {
    let size: CGFloat
    let strokeWidth: CGFloat
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: strokeWidth)
            Circle()
                .strokeBorder(
                    AngularGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .gray.opacity(0.3), location: 0.3),
                            .init(color: .gray.opacity(0.8), location: 0.8),
                            .init(color: .gray, location: 1)
                        ]),
                        center: .center,
                        startAngle: .degrees(-90), // Start from top
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(
                        lineWidth: strokeWidth,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .rotationEffect(Angle(degrees: rotation))
                .onAppear {
                    withAnimation(
                        .linear(duration: 0.8)
                        .repeatForever(autoreverses: false)
                    ) {
                        rotation = 360
                    }
                }
        }
        .frame(width: size, height: size)
    }
}
