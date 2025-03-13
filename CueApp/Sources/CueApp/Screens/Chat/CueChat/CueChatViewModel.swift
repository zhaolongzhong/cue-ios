//
//  CueChatViewModel.swift
//  CueApp
//

import Foundation
import Combine
import CueCommon
import CueOpenAI
import CueAnthropic

@MainActor
public final class CueChatViewModel: BaseChatViewModel {
    private let cueClient: CueClient

    public init(conversationId: String) {
        self.cueClient = CueClient()
        super.init(
            apiKey: "",
            provider: .anthropic,
            model: .claude37Sonnet,
            conversationId: conversationId
        )
    }

    override func sendMessage() async {
        var messageParams = Array(cueChatMessages.suffix(maxMessages))
        let userMessage = CueChatMessage.anthropic(
            Anthropic.ChatMessageParam.userMessage(
                Anthropic.MessageParam(role: "user", content: [Anthropic.ContentBlock(content: richTextFieldState.inputMessage)])
            )
        )

        addOrUpdateMessage(userMessage)
        messageParams.append(userMessage)

        isLoading = true
        richTextFieldState = richTextFieldState.copy(inputMessage: "")

        do {
            let agent = AgentLoop(chatClient: cueClient, toolManager: toolManager, model: model.rawValue)
            let completionRequest = CompletionRequest(model: model.rawValue, tools: tools, toolChoice: "auto")
            let updatedMessages = try await agent.run(with: messageParams, request: completionRequest)

            for message in updatedMessages {
                addOrUpdateMessage(message)
            }
        } catch {
            self.handleError(error)
        }

        isLoading = false
    }

    private func handleError(_ error: Error) {
        self.error = ChatError.unknownError(error.localizedDescription)
        ErrorLogger.log(ChatError.unknownError(error.localizedDescription))
        self.isRunning = false
    }

    override func stopAction() async {
        isRunning = false
        isLoading = false
    }
}
