import Foundation
import Combine

@MainActor
class AnthropicChatViewModel: ObservableObject {
    private let anthropic: Anthropic
    private let toolManager: ToolManager
    private let model = "claude-3-5-haiku-20241022"

    @Published var messages: [Anthropic.ChatMessage] = []
    @Published var newMessage: String = ""
    @Published var isLoading = false
    @Published var availableTools: [MCPTool] = []

    init(apiKey: String) {
        self.anthropic = Anthropic(apiKey: apiKey)
        self.toolManager = ToolManager()
        self.availableTools = toolManager.getMCPTools()
    }

    func startServer() async {
        await self.toolManager.startMcpServer()
        self.availableTools = toolManager.getMCPTools()
    }

    func sendMessage() async {
        let userMessage = Anthropic.ChatMessage.userMessage(Anthropic.MessageParam(role: "user", content: [ContentBlock(content: newMessage)]))
        messages.append(userMessage)

        isLoading = true
        newMessage = ""

        do {
            let tools = toolManager.getMCPTools()
            let response = try await anthropic.messages.create(
                model: self.model,
                maxTokens: 1024,
                messages: messages,
                tools: tools,
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
                        Anthropic.MessageParam(role: "assistant", content: [ContentBlock(content: textBlock.text)])
                    )
                    messages.append(assistantMessage)
                case .toolUse(let toolBlock):
                    // Handle tool use
                    let assistantMessage = Anthropic.ChatMessage.assistantMessage(
                        Anthropic.MessageParam(role: "assistant", content: [ContentBlock(toolUseBlock: toolBlock)])
                    )
                    messages.append(assistantMessage)
                    let toolResult = await handleToolUse(toolBlock)
                    // Add tool response
                    let result = ToolResultContent(
                        isError: false,
                        toolUseId: toolBlock.id,
                        type: "tool_result",
                        content: [ContentBlock(content: toolResult)]
                    )

                    let toolResultMessage = Anthropic.ChatMessage.toolMessage(Anthropic.ToolResultMessage(role: "user", content: [result]))
                    messages.append(toolResultMessage)

                    // Get follow-up response with tool results
                    let followUpResponse = try await anthropic.messages.create(
                        model: self.model,
                        maxTokens: 1024,
                        messages: messages,
                        tools: tools,
                        toolChoice: [
                            "type": "auto"
                        ]
                    )

                    // Process follow-up response
                    for followUpBlock in followUpResponse.content {
                        if case .text(let textBlock) = followUpBlock {
                            let assistantMessage = Anthropic.ChatMessage.assistantMessage(
                                Anthropic.MessageParam(role: "assistant", content: [ContentBlock(content: textBlock.text)])
                            )
                            messages.append(assistantMessage)
                        }
                    }
                }
            }
        } catch {
            AppLog.log.error("Error: \(error)")
            let assistantMessage = Anthropic.ChatMessage.assistantMessage(
                Anthropic.MessageParam(role: "assistant", content: [ContentBlock(content: "Error: \(error.localizedDescription)")])
            )
            messages.append(assistantMessage)
        }

        isLoading = false
    }

    private func handleToolUse(_ toolBlock: ToolUseBlock) async -> String {
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
}
