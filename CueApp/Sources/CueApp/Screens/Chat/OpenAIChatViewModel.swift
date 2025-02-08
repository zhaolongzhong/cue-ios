import Foundation
import CueOpenAI
import Combine

@MainActor
final class OpenAIChatViewModel: ObservableObject {
    private let openAI: OpenAI
    private let toolManager: ToolManager
    #if os(macOS)
    private let axManager: AXManager
    #endif
    private let model: String = "gpt-4o-mini"
    private var cancellables = Set<AnyCancellable>()

    @Published var messages: [OpenAI.ChatMessage] = []
    @Published var newMessage: String = ""
    @Published var isLoading = false
    @Published var availableTools: [Tool] = []
    @Published var error: ChatError?
    @Published var observedApp: AccessibleApplication?
    #if os(macOS)
    private var textAreaContent: TextAreaContent?
    #endif
    @Published var focusedLines: String?

    init(apiKey: String) {
        self.openAI = OpenAI(apiKey: apiKey)
        self.toolManager = ToolManager()
        #if os(macOS)
        self.axManager = AXManager()
        #endif
        self.availableTools = toolManager.getTools()
        setupToolsSubscription()
        setupTextAreaContentSubscription()
    }

    private func setupToolsSubscription() {
        toolManager.mcptoolsPublisher
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.availableTools = self.toolManager.getTools()
            }
            .store(in: &cancellables)
    }

    private func setupTextAreaContentSubscription() {
        #if os(macOS)
        axManager.$textAreaContentList
            .sink { [weak self] newValue in
                guard let self = self else { return }
                self.textAreaContent = newValue.first
                self.focusedLines = self.textAreaContent?.focusedLines
            }
            .store(in: &cancellables)
        #endif
    }

    func startServer() async {
        await self.toolManager.startMcpServer()
    }

    func updateObservedApplication(to newApp: AccessibleApplication) {
        #if os(macOS)
        self.axManager.updateObservedApplication(to: newApp)
        #endif
        self.observedApp = newApp
    }

    func stopObserveApp() {
        #if os(macOS)
        self.axManager.stopObserving()
        self.observedApp = nil
        self.textAreaContent = nil
        #endif
    }

    func sendMessage() async {
        var messageParams = Array(self.messages.suffix(10))
        #if os(macOS)
        if let textAreaContent = self.axManager.textAreaContentList.first {
            let context = textAreaContent.getTextAreaContext()
            let contextMessage = OpenAI.ChatMessage.userMessage(
                OpenAI.MessageParam(role: Role.assistant.rawValue, content: context)
            )
            messageParams.append(contextMessage)
        }
        #endif

        let userMessage = OpenAI.ChatMessage.userMessage(
            OpenAI.MessageParam(role: Role.user.rawValue, content: newMessage)
        )
        self.messages.append(userMessage)
        messageParams.append(userMessage)

        isLoading = true
        newMessage = ""

        do {
            let tools = toolManager.getTools()
            var currentMessages = messageParams
            var iteration = 0
            let maxIterations = 20

            repeat {
                let response = try await openAI.chat.completions.create(
                    model: self.model,
                    messages: currentMessages,
                    tools: tools,
                    toolChoice: "auto"
                )
                guard let message = response.choices.first?.message else { break }

                if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
                    // Append the assistant message triggering the tool calls.
                    let assistantMsg = OpenAI.ChatMessage.assistantMessage(message)
                    messages.append(assistantMsg)
                    currentMessages.append(assistantMsg)

                    // Process tool calls.
                    let toolMessages = await callTools(toolCalls)
                    for toolMessage in toolMessages {
                        let msg = OpenAI.ChatMessage.toolMessage(toolMessage)
                        messages.append(msg)
                        currentMessages.append(msg)
                    }
                } else {
                    // Final assistant response with no tool calls.
                    let assistantMsg = OpenAI.ChatMessage.assistantMessage(message)
                    messages.append(assistantMsg)
                    break
                }
                iteration += 1
            } while iteration < maxIterations

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

#if os(macOS)
extension TextAreaContent {
    func getTextAreaContext() -> String {
        let selectionLinesXML = self.selectionLines.joined(separator: "\n")
        return """
        <full_content>\(self.content)</full_content>
        <selection_lines>\(selectionLinesXML)</selection_lines>
        """
    }

    var focusedLines: String? {
        guard let lineRange = selectionLinesRange else { return nil }
        if lineRange.startLine == lineRange.endLine {
            return "Focused on line \(lineRange.startLine)"
        } else {
            return "Focused on lines \(lineRange.startLine)-\(lineRange.endLine)"
        }
    }
}
#endif
