import Foundation
import CueOpenAI

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: String
    let content: String
}

@MainActor
class OpenAIChatViewModel: ObservableObject {
    private let openAI: OpenAI
    @Published var messages: [ChatMessage] = []
    @Published var newMessage: String = ""
    @Published var isLoading = false

    init(apiKey: String) {
        self.openAI = OpenAI(apiKey: apiKey)
    }

    func sendMessage() async {
        let userMessage = ChatMessage(role: "user", content: newMessage)
        messages.append(userMessage)

        let currentMessages = messages.map { OpenAI.MessageParam(role: $0.role, content: $0.content) }
        isLoading = true
        newMessage = ""

        do {
            let response = try await openAI.chat.completions.create(
                model: "gpt-4o-mini",
                messages: currentMessages
            )

            if let assistantResponse = response.choices.first?.message {
                messages.append(ChatMessage(
                    role: assistantResponse.role,
                    content: assistantResponse.content
                ))
            }
        } catch {
            print("Error: \(error)")
        }
        isLoading = false
    }
}
