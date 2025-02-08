import Foundation
import Combine
import CueCommon
import CueOpenAI
import CueAnthropic

@MainActor
final class AnthropicChatViewModel: ObservableObject {
    private let anthropic: Anthropic
    private let toolManager: ToolManager
    private let model: String = "claude-3-5-haiku-20241022"
    private var cancellables = Set<AnyCancellable>()

    @Published var messages: [Anthropic.ChatMessage] = []
    @Published var newMessage: String = ""
    @Published var isLoading = false
    @Published var availableTools: [Tool] = []
    @Published var error: ChatError?

    init(apiKey: String) {
        self.anthropic = Anthropic(apiKey: apiKey)
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
        let userMessage = Anthropic.ChatMessage.userMessage(
            Anthropic.MessageParam(role: "user", content: [Anthropic.ContentBlock(content: newMessage)])
        )
        messages.append(userMessage)

        isLoading = true
        newMessage = ""

        do {
            let mcpTools = toolManager.getMCPTools()
            let jsonValues = try mcpTools.map { try JSONValue(encodable: $0) }

            let response = try await anthropic.messages.create(
                model: self.model,
                maxTokens: 1024,
                messages: messages,
                tools: jsonValues,
                toolChoice: [
                    "type": "auto"
                ]
            )

            AppLog.log.debug("response: \(String(describing: response))")

            // Process the response content
            for contentBlock in response.content {
                switch contentBlock {
                case .text(let textBlock):
                    // Add assistant's text response
                    let assistantMessage = Anthropic.ChatMessage.assistantMessage(
                        Anthropic.MessageParam(role: "assistant", content: [Anthropic.ContentBlock(content: textBlock.text)])
                    )
                    messages.append(assistantMessage)
                case .toolUse(let toolBlock):
                    // Handle tool use
                    let assistantMessage = Anthropic.ChatMessage.assistantMessage(
                        Anthropic.MessageParam(role: "assistant", content: [Anthropic.ContentBlock(toolUseBlock: toolBlock)])
                    )
                    messages.append(assistantMessage)
                    let toolResult = await handleToolUse(toolBlock)
                    // Add tool response
                    let result = Anthropic.ToolResultContent(
                        isError: false,
                        toolUseId: toolBlock.id,
                        type: "tool_result",
                        content: [Anthropic.ContentBlock(content: toolResult)]
                    )

                    let toolResultMessage = Anthropic.ChatMessage.toolMessage(Anthropic.ToolResultMessage(role: "user", content: [result]))
                    messages.append(toolResultMessage)

                    // Get follow-up response with tool results
                    let followUpResponse = try await anthropic.messages.create(
                        model: self.model,
                        maxTokens: 1024,
                        messages: messages,
                        tools: jsonValues,
                        toolChoice: [
                            "type": "auto"
                        ]
                    )

                    // Process follow-up response
                    for followUpBlock in followUpResponse.content {
                        if case .text(let textBlock) = followUpBlock {
                            let assistantMessage = Anthropic.ChatMessage.assistantMessage(
                                Anthropic.MessageParam(role: "assistant", content: [Anthropic.ContentBlock(content: textBlock.text)])
                            )
                            messages.append(assistantMessage)
                        }
                    }
                }
            }
        } catch let error as Anthropic.Error {
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

    private func handleToolUse(_ toolBlock: Anthropic.ToolUseBlock) async -> String {
        do {
            // Convert tool input to [String: Any]
            var arguments: [String: Any] = [:]
            for (key, value) in toolBlock.input {
                switch value {
                case .string(let str): arguments[key] = str
                case .int(let num): arguments[key] = num
                case .double(let double): arguments[key] = double
                case .bool(let bool): arguments[key] = bool
                case .array(let arr): arguments[key] = arr
                case .dictionary(let dict): arguments[key] = dict
                case .null: arguments[key] = NSNull()
                }
            }

            let result = try await toolManager.callTool(
                name: toolBlock.name,
                arguments: arguments
            )

            return result

        } catch {
            AppLog.log.error("Tool error: \(error)")
            return "Error: \(error.localizedDescription)"
        }
    }

    func clearError() {
        error = nil
    }
}
