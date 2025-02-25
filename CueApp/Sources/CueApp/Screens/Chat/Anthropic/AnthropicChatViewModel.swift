import os
import Foundation
import Combine
import CueCommon
import CueOpenAI
import CueAnthropic

@MainActor
public final class AnthropicChatViewModel: ObservableObject {
    private let anthropic: Anthropic
    private let toolManager: ToolManager
    private var tools: [JSONValue] = []
    private var cancellables = Set<AnyCancellable>()
    private var streamingTask: Task<Void, Error>?
    private var streamingState = StreamingState()
    private var maxTurns: Int = 10
    private let logger = Logger(subsystem: "Anthropic", category: "AnthropicChatViewModel")

    @Published var model: ChatModel = .claude35Sonnet {
        didSet {
            updateTools()
        }
    }
    @Published var messages: [Anthropic.ChatMessageParam] = []
    @Published var newMessage: String = ""
    @Published var isLoading = false
    @Published var availableTools: [Tool] = [] {
        didSet {
            updateTools()
        }
    }
    @Published var error: ChatError?
    @Published var isStreaming = false
    @Published var streamedResponse = ""
    @Published var streamedThinking = ""

    public init(apiKey: String) {
        self.anthropic = Anthropic(apiKey: apiKey)
        self.toolManager = ToolManager(enabledTools: [GmailTool()])
        self.availableTools = toolManager.getTools()
        #if os(macOS)
        setupToolsSubscription()
        #endif
    }

    private func updateTools() {
        tools = self.toolManager.getToolsJSONValue(model: self.model.id)
    }

    private func setupToolsSubscription() {
        toolManager.mcpToolsPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.availableTools = self.toolManager.getTools()
            }
            .store(in: &cancellables)
    }

    func startServer() async {
        #if os(macOS)
        await self.toolManager.startMcpServer()
        #endif
    }

    func sendMessage() async {
        let userMessage = Anthropic.ChatMessageParam.userMessage(
            Anthropic.MessageParam(role: "user", content: [Anthropic.ContentBlock(content: newMessage)])
        )
        messages.append(userMessage)

        isLoading = true
        isStreaming = true
        streamedResponse = ""
        newMessage = ""
        streamingState = StreamingState()

        await streamWithAgentLoop()
    }

    private func handleError(_ error: Error) {
        let chatError: ChatError
        if let anthropicError = error as? Anthropic.Error {
            switch anthropicError {
            case .apiError(let apiError):
                chatError = .apiError(apiError.error.message)
            default:
                chatError = .unknownError(anthropicError.localizedDescription)
            }
        } else {
            chatError = .unknownError(error.localizedDescription)
        }
        self.error = chatError
        ErrorLogger.log(chatError)
    }

    func clearError() {
        error = nil
    }

    func cancelStreaming() {
        streamingTask?.cancel()
        streamingTask = nil
        isLoading = false
        isStreaming = false
    }
}

// MARK: Stream With Agent Loop
extension AnthropicChatViewModel {
    func streamWithAgentLoop() async {
        AppLog.log.debug("Starting agent loop for streaming")

        // Clear previous streaming content
        streamedThinking = ""
        streamedResponse = ""

        // Filter out any empty messages before starting
        messages = messages.filter { $0.hasContent() }

        do {
            let agent = AgentLoop(chatClient: anthropic, toolManager: toolManager, model: model.id)
            let completionRequest = CompletionRequest(
                model: model.id,
                maxTokens: 5000,
                tools: tools,
                toolChoice: "auto",
                maxTurns: maxTurns,
                stream: true
            )

            // Using the enhanced runWithStreaming method that supports multiple iterations
            let updatedMessages = try await agent.runWithStreaming(
                with: messages,
                request: completionRequest,
                onStreamEvent: { [weak self] event in
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }

                        switch event {
                        case .text(let text):
                            self.streamedResponse += text
                        case .toolCall(let toolName, let parameters):
                            // Handle tool call during streaming
                            self.logger.debug("Tool called: \(toolName) with params: \(parameters)")
                            self.streamedResponse += "\n[Calling tool: \(toolName)...]"
                        case .toolResult(let result):
                            // Handle tool result during streaming
                            self.logger.debug("Tool result: \(result)")
                            self.streamedResponse += "\n[Tool result received]"
                        case .thinking(let thinking):
                            // Handle thinking content if available
                            self.streamedThinking += thinking
                        case .completed:
                            // Streaming completely finished (after all iterations)
                            self.logger.debug("Streaming completed")
                        }
                    }
                }
            )

            // Final filtering to remove any empty messages and ensure proper order
            let filteredMessages = validateMessageSequence(updatedMessages.filter { $0.hasContent() })

            // Update the conversation with all messages (including tool calls and results)
            self.messages = filteredMessages

        } catch {
            handleError(error)
        }

        isLoading = false
        isStreaming = false
    }

    // Helper method to validate that tool uses are always followed by tool results
    private func validateMessageSequence(_ messages: [Anthropic.ChatMessageParam]) -> [Anthropic.ChatMessageParam] {
        var validatedMessages: [Anthropic.ChatMessageParam] = []
        var pendingToolUse = false

        for message in messages {
            switch message {
            case .assistantMessage(let param):
                // Check if this message contains tool uses
                for block in param.content {
                    if case .toolUse = block {
                        pendingToolUse = true
                        break
                    }
                }
                validatedMessages.append(message)

            case .toolMessage:
                // This is a tool result message
                if pendingToolUse {
                    pendingToolUse = false
                }
                validatedMessages.append(message)

            default:
                validatedMessages.append(message)
            }
        }

        // If we end with a pending tool use without result, log error
        if pendingToolUse {
            logger.error("Message sequence ends with tool use without corresponding tool result")
        }

        return validatedMessages
    }
}

// MARK: Run With Streaming
extension AgentLoop where Client == Anthropic {
    func runWithStreaming(
        with messages: [Anthropic.ChatMessageParam],
        request: CompletionRequest,
        onStreamEvent: @escaping (StreamEvent) async -> Void
    ) async throws -> [Anthropic.ChatMessageParam] {
        // Filter out any empty messages
        var currentMessages = messages.filter { message in
            switch message {
            case .assistantMessage(let param):
                return !param.content.isEmpty
            default:
                return true
            }
        }

        var iteration = 0
        var shouldContinue = true
        let maxIterations = request.maxTurns
        let thinking = Anthropic.Thinking(type: "enabled", budgetTokens: 1024)

        logger.debug("Starting streaming with \(currentMessages.count) messages")

        while shouldContinue && iteration < maxIterations {
            shouldContinue = false
            logger.debug("Iteration \(iteration) with \(currentMessages.count) messages")

            let delegate = createStreamingDelegate(onStreamEvent: onStreamEvent)

            // Start streaming
            logger.debug("Sending streaming request")
            let streamTask = try await chatClient.messages.streamCreate(
                model: request.model,
                maxTokens: request.maxTokens ?? 4096,
                messages: currentMessages,
                tools: request.tools,
                toolChoice: request.toolChoice != nil ? ["type": request.toolChoice!] : nil,
                thinking: thinking,
                delegate: delegate
            )

            // Wait for completion
            try await streamTask.value
            logger.debug("Streaming completed for iteration \(iteration)")

            // Wait for any tool calls to complete and ensure tool results are available before continuing
            await delegate.waitForToolResults()

            // Process results from this iteration
            processIterationResults(delegate: delegate, currentMessages: &currentMessages, shouldContinue: &shouldContinue)
            if !shouldContinue {
                break
            }

            // Continue to next iteration if needed
            iteration += 1
            if shouldContinue && iteration < maxIterations {
                await onStreamEvent(.text("\n\nAnalyzing the tool results...\n\n"))
            }
        }

        await onStreamEvent(.completed)
        return currentMessages
    }

    private func createStreamingDelegate(
        onStreamEvent: @escaping (StreamEvent) async -> Void
    ) -> AnthropicStreamingDelegate {
        return AnthropicStreamingDelegate(
            toolManager: self.toolManager,
            onEvent: onStreamEvent,
            onToolCall: { toolName, params in
                do {
                    if let toolManager = self.toolManager {
                        let result = try await toolManager.callTool(name: toolName, arguments: params)
                        await onStreamEvent(.toolResult(result))
                        return result
                    } else {
                        let errorMsg = "No tool manager available to handle tool: \(toolName)"
                        await onStreamEvent(.toolResult(errorMsg))
                        return errorMsg
                    }
                } catch {
                    let errorMessage = "Error executing tool \(toolName): \(error.localizedDescription)"
                    await onStreamEvent(.toolResult(errorMessage))
                    return errorMessage
                }
            }
        )
    }

    private func processIterationResults(
        delegate: AnthropicStreamingDelegate,
        currentMessages: inout [Anthropic.ChatMessageParam],
        shouldContinue: inout Bool
    ) {
        guard let finalMessage = delegate.finalMessage else { return }

        logger.debug("Adding final message")

        // Check if the message has tool uses
        var hasToolUses = finalMessage.hasToolUse()

        // If message has tool uses, verify we have corresponding tool results
        if hasToolUses && delegate.hasCompleteToolResults() {
            // Add assistant message and tool results
            currentMessages.append(finalMessage)

            // Add tool results immediately after the message with tool uses
            for toolResult in delegate.toolResults {
                currentMessages.append(.toolMessage(toolResult))
            }
            shouldContinue = true
        } else if !hasToolUses {
            // No tool uses, safe to add the message
            currentMessages.append(finalMessage)
            shouldContinue = true
        } else {
            // Tool use without results - error case
            logger.error("Tool use without corresponding tool result. Cannot continue.")
            shouldContinue = false
        }
    }
}
