//
//  LocalChatViewModel.swift
//  CueApp
//

import os
import Foundation
import SwiftUI
import Combine
import Dependencies
import CueCommon
import CueOpenAI

@MainActor
public final class LocalChatViewModel: BaseChatViewModel {
    @AppStorage(ProviderSettingsKeys.SelectedConversation.local) private var storedConversationId: String?

    // Streaming state
    var streamingStates: [String: StreamingState] = [:]
    @Published private(set) var streamingMessageId: String?
    @Published var streamingMessageContent: String = ""
    @Published var baseURL: String = ""

    private let localClient: LocalClient
    private var currentTurn: Int = 0
    public let logger = Logger(subsystem: "Local", category: "LocalChatViewModel")

    public init(apiKey: String = "") {
        self.localClient = LocalClient()

        super.init(
            apiKey: apiKey,
            provider: .local,
            model: .deepSeekR17B
        )
    }

    func resetMessages() {
        self.cueChatMessages.removeAll()
        guard let conversationId = selectedConversationId else { return }

        Task {
            await messageRepository.deleteAllCachedMessages(forConversation: conversationId)
        }
    }

    func prepareForMessageParams(_ messageParams: [CueChatMessage]) -> [OpenAI.ChatMessageParam] {
        let openAIChatMessageParams = messageParams.compactMap { message -> OpenAI.ChatMessageParam? in
            switch message {
            case .local(let msg, _, _, _), .openAI(let msg, _, _, _):
                switch msg {
                case .userMessage(let userMessage):
                    return OpenAI.ChatMessageParam.userMessage(.init(role: "user", contentString: userMessage.contentAsString))
                default:
                    return msg
                }
            default:
                return nil
            }
        }
        return openAIChatMessageParams
    }

    func sendMessageWithoutStream(_ chatMessages: [CueChatMessage]) async throws {
        logger.debug("Send message without streaming")
        let messageParams = prepareForMessageParams(chatMessages)

        let completionRequest = CompletionRequest(
            model: model.id,
            tools: isToolEnabled ? tools : [],
            toolChoice: isToolEnabled ? "auto" : nil
        )
        let agent = AgentLoop(chatClient: localClient, toolManager: toolManager, model: model.id)
        let updatedMessages = try await agent.run(with: messageParams, request: completionRequest)
        for updatedMessage in updatedMessages {
            let cueChatMessage = CueChatMessage.openAI(updatedMessage)
            addOrUpdateMessage(cueChatMessage, persistInCache: true)
        }
    }

    func sendMessageStream(_ chatMessages: [CueChatMessage]) async throws {
        logger.debug("Send message with streaming")
        let messageParams = prepareForMessageParams(chatMessages)

        // Initialize a new streaming state for this message.
        let id = UUID().uuidString
        streamingMessageId = id
        streamingStates[id] = StreamingState(startTime: Date(), isStreamingMode: true)

        do {
            try await localClient.sendStream(
                model: self.model.rawValue,
                messages: messageParams,
                tools: isToolEnabled ? tools : [],
                toolChoice: isToolEnabled ? "auto" : nil
            ) { [weak self] chunk in
                guard let self = self, let id = self.streamingMessageId else { return }

                self.streamingStates[id]?.chunks.append(chunk)

                if let content = chunk.message.content {
                    self.streamingStates[id]?.content += content
                    self.updateStreamingMessage(for: id, content: self.streamingStates[id]?.content ?? "", isComplete: chunk.done)
                }
                if let toolCalls = chunk.message.toolCalls {
                    logger.debug("Tool calls: \(toolCalls)")
                    self.streamingStates[id]?.toolCalls.append(contentsOf: toolCalls)
                    self.updateStreamingMessage(for: id, content: self.streamingStates[id]?.content ?? "", isComplete: chunk.done)
                }

                if chunk.done {
                    logger.debug("Chunk done: \(String(describing: chunk)), \(String(describing: self.streamingStates[id]?.content))")
                    self.streamingStates[id]?.isComplete = true
                    self.streamingStates[id]?.endTime = chunk.createdAt
                    // Clear the current streaming id once finished.
                    self.streamingMessageId = nil
                    self.updateStreamingMessage(for: id, content: self.streamingStates[id]?.content ?? "", isComplete: chunk.done)
                    if let toolCalls = self.streamingStates[id]?.toolCalls, !toolCalls.isEmpty {
                        Task {
                            await self.handleStreamingToolCalls(toolCalls)
                        }
                    }
                }
            }
        } catch {
            let chatError = ChatError.unknownError(error.localizedDescription)
            self.error = chatError
            ErrorLogger.log(chatError)
            self.streamingMessageId = nil
        }
        isLoading = false
    }

    func handleStreamingToolCalls(_ toolCalls: [ToolCall]) async {
        logger.debug("Handle streaming tool calls: \(toolCalls)")
        guard toolCalls.isEmpty == false else {
            return
        }
        let toolMessages = await toolManager.callTools(toolCalls)
        for tm in toolMessages {
            let nativeToolMsg = OpenAI.ChatMessageParam.toolMessage(tm)
            addOrUpdateMessage(.openAI(nativeToolMsg))
        }
        currentTurn += 1
        if currentTurn >= maxTurns {
            logger.debug("Max turn reached, stopping streaming.")
            return
        }
        Task {
            let messageParams = Array(self.cueChatMessages.suffix(maxMessages))
            try await sendMessageStream(messageParams)
        }
    }

    override func sendMessage() async {
        let (userMessage, _) = await prepareOpenAIMessage()

        // Add user message to chat
        let cueChatMessage = CueChatMessage.openAI(userMessage, stableId: UUID().uuidString)
        addOrUpdateMessage(cueChatMessage, persistInCache: true)

        // Get recent messages
        let messageParams = Array(self.cueChatMessages.suffix(maxMessages))

        isLoading = true
        richTextFieldState = richTextFieldState.copy(inputMessage: "")
        currentTurn = 0

        do {
            if isStreamingEnabled {
                try await sendMessageStream(messageParams)
            } else {
                try await sendMessageWithoutStream(messageParams)
            }
        } catch {
            let chatError = ChatError.unknownError(error.localizedDescription)
            self.error = chatError
            ErrorLogger.log(chatError)
        }

        isLoading = false
    }

    override func stopAction() async {
        isRunning = false
        isLoading = false
    }

    // MARK: Streaming
    private func updateStreamingMessage(for id: String, content: String, isComplete: Bool = false) {
        var updatedContent = content
        if updatedContent.hasPrefix("<think>"), updatedContent.contains("</think>"), streamingStates[id]?.thinkingEndTime == nil {
            streamingStates[id]?.thinkingEndTime = Date()
        }
        if updatedContent.hasPrefix("<think>"), !updatedContent.contains("</think>") {
            updatedContent += "</think>"
        }
        streamingStates[id]?.isComplete = isComplete

        let newMessage = CueChatMessage.streamingMessage(
            id: id,
            content: updatedContent,
            toolCalls: streamingStates[id]?.toolCalls ?? [],
            streamingState: streamingStates[id]
        )
        if streamingMessageId == id {
            self.streamingMessageContent = updatedContent
        }
        addOrUpdateMessage(newMessage, persistInCache: isComplete)
    }
}
