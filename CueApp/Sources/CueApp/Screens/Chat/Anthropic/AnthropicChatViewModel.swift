//
//  AnthropicChatViewModel.swift
//  CueApp
//

import os
import Foundation
import SwiftUI
import Combine
import CueCommon
import Dependencies
import CueOpenAI
import CueAnthropic

@MainActor
public final class AnthropicChatViewModel: BaseChatViewModel, ChatViewModel {
    // Streaming state
    var streamingStates: [String: StreamingState] = [:]
    @Published var streamedMessages: [String: String] = [:]
    @Published var streamedMessage: String = ""
    @Published var streamedThinkings: [String: String] = [:]
    @Published var streamedThinking: String = ""

    @Published var currentStreamState: StreamingState? {
        didSet {
            if let newState = currentStreamState, let id = newState.id {
                if let index = cueChatMessages.firstIndex(where: { $0.id == newState.id }) {
                    let newMessage = CueChatMessage.streamingAnthropicMessage(
                        id: id,
                        streamingState: newState
                    )
                    cueChatMessages[index] = newMessage
                } else {
                    let newMessage = CueChatMessage.streamingAnthropicMessage(
                        id: id,
                        streamingState: newState
                    )
                    cueChatMessages.append(newMessage)
                }
            }
        }
    }

    private var currentTurn: Int = 0
    let logger = Logger(subsystem: "Anthropic", category: "AnthropicChatViewModel")
    let anthropic: Anthropic
    var streamingTask: Task<Void, Error>?

    public init(apiKey: String) {
        self.anthropic = Anthropic(apiKey: apiKey)

        super.init(
            apiKey: apiKey,
            provider: .anthropic,
            model: .claude37Sonnet,
            conversationId: nil
        )
        self.availableTools = toolManager.getTools()
        updateTools()
    }

    private func resetStreamingState() {
        streamedMessages.removeAll()
        streamedThinkings.removeAll()
        streamedThinking = ""
    }

    func cancelStreaming() {
        streamingTask?.cancel()
        streamingTask = nil
        isLoading = false
    }

    // Helper method to update messages by replacing existing ones and adding new ones
    func updateChatMessages(with updatedMessages: [CueChatMessage]) {
        // Create a dictionary of existing messages by ID for fast lookup
        var existingMessagesById = [String: Int]()
        for (index, message) in cueChatMessages.enumerated() {
            existingMessagesById[message.id] = index
        }

        // Process each updated message
        for updatedMessage in updatedMessages {
            let newChatMessage = CueChatMessage.anthropic(
                updatedMessage.anthropic,
                stableId: updatedMessage.id,
                streamingState: streamingStates[updatedMessage.id]
            )
            addOrUpdateMessage(newChatMessage)
        }
    }

    override func sendMessage() async {
        let (userMessage, _) = await prepareAnthropicMessage()

        // Add user message to chat
        let cueChatMessage = CueChatMessage.anthropic(userMessage, stableId: UUID().uuidString)
        addOrUpdateMessage(cueChatMessage)

        // Get updated message list including the newly added message
        let messageParams = Array(self.cueChatMessages.suffix(maxMessages))

        isLoading = true
        resetStreamingState()
        newMessage = ""

        await streamWithAgentLoop(messageParams)
        isLoading = false
    }
}
