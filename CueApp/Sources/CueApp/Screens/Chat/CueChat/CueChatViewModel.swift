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
public final class CueChatViewModel: BaseChatViewModel, ChatViewModel {
    private let cueClient: CueClient

    public init() {
        self.cueClient = CueClient()
        super.init(
            apiKey: "",
            provider: .anthropic,
            model: .claude37Sonnet
        )
    }

    override func sendMessage() async {
        var messageParams = Array(cueChatMessages.suffix(maxMessages))
        let userMessage = CueChatMessage.anthropic(
            Anthropic.ChatMessageParam.userMessage(
                Anthropic.MessageParam(role: "user", content: [Anthropic.ContentBlock(content: newMessage)])
            )
        )

        addOrUpdateMessage(userMessage)
        messageParams.append(userMessage)

        isLoading = true
        newMessage = ""

        do {
            let agent = AgentLoop(chatClient: cueClient, toolManager: toolManager, model: model.rawValue)
            let completionRequest = CompletionRequest(model: model.rawValue, tools: tools, toolChoice: "auto")
            let updatedMessages = try await agent.run(with: messageParams, request: completionRequest)

            for message in updatedMessages {
                addOrUpdateMessage(message)
            }
        } catch {
            self.error = ChatError.unknownError(error.localizedDescription)
            ErrorLogger.log(ChatError.unknownError(error.localizedDescription))
        }

        isLoading = false
    }
}
