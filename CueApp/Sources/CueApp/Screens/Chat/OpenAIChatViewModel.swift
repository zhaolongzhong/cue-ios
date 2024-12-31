import Foundation
import CueOpenAI
import Combine

@MainActor
final class OpenAIChatViewModel: ObservableObject {
    private let openAI: OpenAI
    private let toolManager: ToolManager
    private let model: String = "gpt-4o-mini"
    private var cancellables = Set<AnyCancellable>()

    @Published var messages: [OpenAI.ChatMessage] = []
    @Published var newMessage: String = ""
    @Published var isLoading = false
    @Published var availableTools: [Tool] = []
    @Published var error: ChatError?

    init(apiKey: String) {
        self.openAI = OpenAI(apiKey: apiKey)
        self.toolManager = ToolManager()
        self.availableTools = toolManager.getTools()
        setupToolsSubscription()
    }

    private func setupToolsSubscription() {
        toolManager.mcptoolsPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.availableTools = self.toolManager.getTools()
            }
            .store(in: &cancellables)
    }

    func startServer() async {
        await self.toolManager.startMcpServer()
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
                model: self.model,
                messages: messages,
                tools: tools,
                toolChoice: "auto"
            )

            AppLog.log.debug("response: \(String(describing: response))")

            guard let assistantResponse = response.choices.first?.message else {
                return
            }

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
                    model: self.model,
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
        } catch let error as OpenAI.Error {
            let chatError: ChatError
            switch error {
            case .apiError(let apiError):
                chatError = .apiError(apiError.error.message)
            default:
                chatError = .unknownError(error.localizedDescription)
            }
            self.error = chatError
            ErrorLogger.log(chatError)
        } catch {
            let chatError = ChatError.unknownError(error.localizedDescription)
            self.error = chatError
            ErrorLogger.log(chatError)
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
                    let toolError = ChatError.toolError(error.localizedDescription)
                    ErrorLogger.log(toolError)
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

    func clearError() {
        error = nil
    }
}
