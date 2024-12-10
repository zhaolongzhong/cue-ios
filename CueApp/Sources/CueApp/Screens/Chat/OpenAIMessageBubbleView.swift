import SwiftUI
import CueOpenAI

struct OpenAIMessageBubble: View {
    let message: OpenAI.ChatMessage

    var body: some View {
        HStack {
            if message.role == "user" {
                Spacer()
            }

            Text(message.content)
                .padding()
                .background(message.role == "user" ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(message.role == "user" ? .white : .primary)
                .cornerRadius(16)

            if message.role != "user" {
                Spacer()
            }
        }
    }
}
