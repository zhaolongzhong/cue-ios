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

    func cancelStreaming() {
        streamingTask?.cancel()
        streamingTask = nil
        isLoading = false
    }

    // Helper method to update messages by replacing existing ones and adding new ones
    func updateChatMessages(with updatedMessages: [CueChatMessage]) {
        // Process each updated message
        for updatedMessage in updatedMessages {
            let newChatMessage = CueChatMessage.anthropic(
                updatedMessage.anthropic,
                stableId: updatedMessage.id,
                streamingState: streamingStates[updatedMessage.id]
            )
            addOrUpdateMessage(newChatMessage, persistInCache: true)
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
        newMessage = ""

        await streamWithAgentLoop(messageParams)
        isLoading = false
    }
}
