import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    @Environment(\.colorScheme) private var colorScheme

    private var bubbleColor: Color {
        if message.isFromUser {
            return AppTheme.Colors.Message.userBubble
        } else {
            return colorScheme == .light ? AppTheme.Colors.Message.assistantBubble : AppTheme.Colors.Message.assistantBubbleDark
        }
    }

    private var textColor: Color {
        if message.isFromUser {
            return .white
        } else {
            return colorScheme == .light ? .primary : .white
        }
    }

    var body: some View {
        HStack {
            if message.isFromUser { Spacer() }

            Text(message.content)
                .padding(12)
                .background(bubbleColor)
                .foregroundColor(textColor)
                .clipShape(BubbleShape(isFromUser: message.isFromUser))
                .overlay(
                    BubbleShape(isFromUser: message.isFromUser)
                        .stroke(
                            !message.isFromUser && colorScheme == .light
                            ? Color(white: 0.8)
                            : Color.clear,
                            lineWidth: 1
                        )
                )

            if !message.isFromUser { Spacer() }
        }
    }
}

// Custom bubble shape for messages
struct BubbleShape: Shape {
    let isFromUser: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 16
        let path = Path { p in
            p.move(to: CGPoint(x: rect.minX, y: rect.maxY))

            // Bottom left corner
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            p.addArc(
                center: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
                radius: radius,
                startAngle: .degrees(180),
                endAngle: .degrees(270),
                clockwise: false
            )

            // Top edge
            p.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            p.addArc(
                center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
                radius: radius,
                startAngle: .degrees(270),
                endAngle: .degrees(0),
                clockwise: false
            )

            // Right edge
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
            p.addArc(
                center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius),
                radius: radius,
                startAngle: .degrees(0),
                endAngle: .degrees(90),
                clockwise: false
            )

            // Bottom edge
            p.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
            p.addArc(
                center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
                radius: radius,
                startAngle: .degrees(90),
                endAngle: .degrees(180),
                clockwise: false
            )
        }
        return path
    }
}
