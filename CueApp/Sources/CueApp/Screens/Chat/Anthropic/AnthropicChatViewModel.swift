//
//  AnthropicChatViewModel.swift
//  CueApp
//

import os
import Foundation
import SwiftUI
import Combine
import CueCommon
import CueOpenAI
import CueAnthropic

@MainActor
public final class AnthropicChatViewModel: BaseChatViewModel {
    @Published var currentStreamState: StreamingState? {
        didSet {
            if let newState = currentStreamState, let id = newState.id {
                let newMessage = CueChatMessage.streamingAnthropicMessage(
                    id: id,
                    streamingState: newState
                )
                addOrUpdateMessage(newMessage, persistInCache: false)
            }
        }
    }

    private var currentTurn: Int = 0
    var streamingStates: [String: StreamingState] = [:]
    let logger = Logger(subsystem: "Anthropic", category: "AnthropicChatViewModel")
    let anthropic: Anthropic
    var streamingTask: Task<Void, Error>?

    public init(conversationId: String?, apiKey: String) {
        self.anthropic = Anthropic(apiKey: apiKey)

        super.init(
            apiKey: apiKey,
            provider: .anthropic,
            model: .claude37Sonnet,
            conversationId: conversationId,
            richTextFieldState: RichTextFieldState(showAXApp: true)
        )
    }

    override func sendMessage() async {
        let (userMessage, _) = await prepareAnthropicMessage()

        // Add user message to chat
        let cueChatMessage = CueChatMessage.anthropic(userMessage, stableId: UUID().uuidString, createdAt: Date())
        addOrUpdateMessage(cueChatMessage, persistInCache: true)

        // Get updated message list including the newly added message
        let messageParams = Array(self.cueChatMessages.suffix(maxMessages))

        isLoading = true
        isRunning = true
        richTextFieldState.inputMessage = ""

        await startStreamingTask(messageParams)
    }

    func cancelStreaming() {
        streamingTask?.cancel()
        streamingTask = nil
        isLoading = false
    }

    func updateChatMessages(with updatedMessages: [CueChatMessage]) {
        for updatedMessage in updatedMessages {
            guard  let param = updatedMessage.anthropicChatParam else {
                continue
            }
            let newChatMessage = CueChatMessage.anthropic(
                param,
                stableId: updatedMessage.id,
                streamingState: streamingStates[updatedMessage.id],
                createdAt: updatedMessage.createdAt
            )
            addOrUpdateMessage(newChatMessage, persistInCache: true)
        }
        isRunning = false
    }
}

// MARK: Start Streaming Task

extension AnthropicChatViewModel {
    func startStreamingTask(_ messageParams: [CueChatMessage]) async {
        AppLog.log.debug("Starting streaming conversation: \(String(describing: self.selectedConversationId))")

        let thinking = Anthropic.Thinking(type: "enabled", budgetTokens: 1024)
        let request = CompletionRequest(
            model: model.id,
            messages: messageParams,
            maxTokens: 5000,
            tools: tools.isEmpty ? nil : tools,
            toolChoice: tools.isEmpty ? nil : "auto",
            maxTurns: maxTurns,
            thinking: thinking,
            stream: true
        )

        do {
            streamingTask = Task {
                let updatedMessages = try await runLoop(
                    request: request,
                    onStreamEvent: { [weak self] event in
                        Task { @MainActor [weak self] in
                            guard let self = self else { return }

                            // Process the event based on its type
                            self.handleStreamEvent(event)
                        }
                    }
                )

                let filteredMessages = validateMessageSequence(updatedMessages)
                updateChatMessages(with: filteredMessages)
            }

            // Wait for completion or cancellation
            try await streamingTask?.value

        } catch {
            handleError(error)
        }

        isLoading = false
    }

    // Helper method to validate that tool uses are always followed by tool results
    private func validateMessageSequence(_ messages: [CueChatMessage]) -> [CueChatMessage] {
        var validatedMessages: [CueChatMessage] = []
        var pendingToolUse = false

        for message in messages.filter({ $0.isAnthropic }) {
            switch message.anthropicChatParam {
            case .assistantMessage(let param, _):
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
}

// MARK: - Update UI
extension AnthropicChatViewModel {
    private func handleStreamEvent(_ event: StreamEvent) {
        switch event {
        case .streamTaskStarted(let id):
            initializeStreamingStates(id)

        case .streamTaskCompleted(let id):
            if var state = streamingStates[id] {
                state.isComplete = true
                state.endTime = Date()
                streamingStates[id] = state
            }

        case .text(let id, let text):
            updateStreamingStateWithText(id, text)
        case .thinking(let id, let thinking):
            updateStreamingStateWithThinking(id, thinking)
        case .thinkingSignature(let id, let isComplete):
            if isComplete == true, var state = streamingStates[id] {
                state.thinkingEndTime = Date()
                streamingStates[id] = state
            }
        case .toolCall(let id, let toolUseblocks):
            updateStreamingStateWithToolUseBlocks(id, toolUseblocks)
        case .toolResult(_, let msg):
            addOrUpdateMessage(msg, persistInCache: false)
        default:
            break
        }
    }

    func initializeStreamingStates(_ id: String) {
        // Initialize streaming state for this ID
        currentStreamState = StreamingState(
            id: id,
            content: "",
            isComplete: false,
            startTime: Date(),
            isStreamingMode: true
        )
        streamingStates[id] = currentStreamState
    }

    func updateStreamingStateWithText(_ id: String, _ text: String) {
        if var state = streamingStates[id] {
            state.content += text
            streamingStates[id] = state
        }

        // Update the streamed content
        if var state = streamingStates[id] {
            if let textBlock = state.contentBlocks.filter({ $0.isText }).first {
                state.contentBlocks[state.contentBlocks.firstIndex(of: textBlock)!] = Anthropic.ContentBlock(content: textBlock.text + text)
            } else {
                state.contentBlocks.append(Anthropic.ContentBlock(content: text))
            }
            streamingStates[id] = state
            currentStreamState = state
        }
    }

    func updateStreamingStateWithThinking(_ id: String, _ thinking: String) {
        if var state = streamingStates[id] {
            if let contentBlock = state.contentBlocks.filter({ $0.isThinking }).first, case .thinking(let thinkingBlock) = contentBlock {
                state.contentBlocks[state.contentBlocks.firstIndex(of: contentBlock)!] = Anthropic.ContentBlock(thinkingBlock: Anthropic.ThinkingBlock(type: thinkingBlock.type, thinking: thinkingBlock.thinking + thinking, signature: thinkingBlock.signature))
            } else {
                state.contentBlocks.append(Anthropic.ContentBlock(thinkingBlock: Anthropic.ThinkingBlock(type: "thinking", thinking: thinking, signature: "")))
            }
            streamingStates[id] = state
            currentStreamState = state
        }
    }

    func updateStreamingStateWithToolUseBlocks(_ id: String, _ toolUseBlocks: [Anthropic.ToolUseBlock]) {
        if var state = streamingStates[id] {
            let existingToolUseIds = state.contentBlocks.compactMap { block -> String? in
                if case .toolUse(let toolUseBlock) = block {
                    return toolUseBlock.id
                }
                return nil
            }
            let newToolUseBlocks = toolUseBlocks.filter { !existingToolUseIds.contains($0.id) }
            for toolUseBlock in newToolUseBlocks {
                state.contentBlocks.append(.toolUse(toolUseBlock))
            }
            streamingStates[id] = state
            currentStreamState = state
        }
    }
}
