import SwiftUI

struct AnimatedText: View {
    let text: String
    @State private var progress: CGFloat = -0.3

    var body: some View {
        ZStack(alignment: .leading) {
            Text(text)
                .foregroundColor(.secondary)
            Text(text)
                .foregroundColor(.primary)
                .mask(
                    GeometryReader { _ in
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .white, location: 0.2),
                                .init(color: .white, location: 0.8),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: UnitPoint(x: progress, y: 0),
                            endPoint: UnitPoint(x: progress + 0.5, y: 0)
                        )
                    }
                )
        }
        .onAppear {
            withAnimation(
                .linear(duration: 1.3)
                .repeatForever(autoreverses: false)
            ) {
                progress = 1.3
            }
        }
    }
}
