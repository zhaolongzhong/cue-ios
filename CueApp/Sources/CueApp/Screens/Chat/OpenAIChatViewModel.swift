import Foundation
import CueOpenAI

@MainActor
class OpenAIChatViewModel: ObservableObject {
    private let openAI: OpenAI
    private let toolManager: ToolManager

    @Published var messages: [OpenAI.ChatMessage] = []
    @Published var newMessage: String = ""
    @Published var isLoading = false

    init(apiKey: String) {
        self.openAI = OpenAI(apiKey: apiKey)
        self.toolManager = ToolManager()
    }

    func sendMessage() async {
        let userMessage = OpenAI.ChatMessage.userMessage(
            OpenAI.MessageParam(role: "user", content: newMessage)
        )
        messages.append(userMessage)

        isLoading = true
        newMessage = ""

        do {
            let tools = toolManager.getTools()

            let response = try await openAI.chat.completions.create(
                model: "gpt-4o-mini",
                messages: messages,
                tools: tools,
                toolChoice: "auto"
            )

            AppLog.log.debug("response: \(String(describing: response))")

            if let assistantResponse = response.choices.first?.message {
                if let toolCalls = assistantResponse.toolCalls {
                    let toolMessages = await callTools(toolCalls)

                    let assistantMessage = OpenAI.ChatMessage.assistantMessage(
                        assistantResponse
                    )
                    messages.append(assistantMessage)
                    for toolMessage in toolMessages {
                        messages.append(OpenAI.ChatMessage.toolMessage(toolMessage))
                    }

                    // Get the final response with tool results
                    let finalResponse = try await openAI.chat.completions.create(
                        model: "gpt-4o-mini",
                        messages: messages,
                        tools: tools,
                        toolChoice: "auto"
                    )

                    if let finalMessage = finalResponse.choices.first?.message {
                        let assistantMessage = OpenAI.ChatMessage.assistantMessage(
                            finalMessage
                        )
                        messages.append(assistantMessage)
                    }
                } else {
                    // Normal message without tool calls
                    let assistantMessage = OpenAI.ChatMessage.assistantMessage(
                        assistantResponse
                    )
                    messages.append(assistantMessage)
                }
            }
        } catch {
            AppLog.log.error("Error: \(error)")
        }
        isLoading = false
    }

    private func callTools(_ toolCalls: [ToolCall]) async -> [OpenAI.ToolMessage] {
        var results: [OpenAI.ToolMessage] = []

        for toolCall in toolCalls {
            if let data = toolCall.function.arguments.data(using: .utf8),
               let args = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                do {
                    let result = try await toolManager.callTool(
                        name: toolCall.function.name,
                        arguments: args
                    )
                    results.append(OpenAI.ToolMessage(
                        role: "tool",
                        content: result,
                        toolCallId: toolCall.id
                    ))
                } catch {
                    AppLog.log.error("Tool error: \(error)")
                    results.append(OpenAI.ToolMessage(
                        role: "tool",
                        content: "Error: \(error.localizedDescription)",
                        toolCallId: toolCall.id
                    ))
                }
            }
        }

        return results
    }
}
