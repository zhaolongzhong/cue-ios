//
//  OpenAIChatViewModel.swift
//  CueApp
//

import Foundation
import Combine
import Dependencies
import CueCommon
import CueOpenAI

@MainActor
public final class OpenAIChatViewModel: BaseChatViewModel, ChatViewModel {
    private let openAI: OpenAI

    public init(apiKey: String, conversationId: String? = nil) {
        self.openAI = OpenAI(apiKey: apiKey)
        super.init(
            apiKey: apiKey,
            provider: .openai,
            model: .gpt4oMini,
            conversationId: conversationId
        )
    }

    override func sendMessage() async {
        let (userMessage, _, _) = await prepareOpenAIMessage()

        // Add user message to chat
        let cueChatMessage = CueChatMessage.openAI(userMessage, stableId: UUID().uuidString)
        addOrUpdateMessage(cueChatMessage)

        // Get recent messages
        let messageParams = Array(self.cueChatMessages.suffix(maxMessages))

        isLoading = true
        newMessage = ""
        attachments.removeAll()

        do {
            let agent = AgentLoop(chatClient: openAI, toolManager: toolManager, model: model.id)
            let completionRequest = CompletionRequest(model: model.id, tools: tools, toolChoice: "auto")
            let openAIParams = messageParams.compactMap { $0.openAIChatParam }
            let updatedMessages = try await agent.run(with: openAIParams, request: completionRequest)
            for message in updatedMessages {
                let cueChatMessage = CueChatMessage.openAI(message, stableId: UUID().uuidString)
                addOrUpdateMessage(cueChatMessage)
            }
        } catch {
            let chatError = ChatError.unknownError(error.localizedDescription)
            self.error = chatError
            ErrorLogger.log(chatError)
        }
        isLoading = false
    }
}
