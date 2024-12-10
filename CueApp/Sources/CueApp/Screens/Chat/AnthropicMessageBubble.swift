import SwiftUI

struct AnthropicMessageBubble: View {
    let message: Anthropic.ChatMessage

    var body: some View {
        HStack {
            if message.role == "user" {
                Spacer()
            }

            Text(message.content)
                .padding()
                .background(backgroundColor)
                .foregroundColor(foregroundColor)
                .textSelection(.enabled)
                .cornerRadius(16)

            if message.role != "user" {
                Spacer()
            }
        }
    }

    private var backgroundColor: Color {
        switch message.role {
        case "user":
            return .blue
        case "assistant":
            return .gray.opacity(0.2)
        case "system":
            return .red.opacity(0.2)
        case "tool":
            return .green.opacity(0.2)
        default:
            return .gray.opacity(0.2)
        }
    }

    private var foregroundColor: Color {
        switch message.role {
        case "user":
            return .white
        default:
            return .primary
        }
    }
}
