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

    override func updateTools() {
        super.updateTools()
        // Any OpenAI-specific tool configuration can go here
    }

    override func sendMessage() async {
        var messageParams = Array(self.cueChatMessages.suffix(maxMessages))

        #if os(macOS)
        if let textAreaContent = self.axManager.textAreaContentList.first {
            let context = textAreaContent.getTextAreaContext()
            let contextMessage = OpenAI.ChatMessageParam.assistantMessage(
                OpenAI.AssistantMessage(role: Role.assistant.rawValue, content: context)
            )
            messageParams.append(.openAI(contextMessage))
        }
        #endif

        var contentBlocks: [OpenAI.ContentBlock] = []
        if !newMessage.isEmpty {
            let textBlock = OpenAI.ContentBlock(
                type: .text,
                text: newMessage
            )
            contentBlocks.append(textBlock)
        }

        let attachmentContentBlocks = await convertToContents(attachments: attachments)
        if !attachmentContentBlocks.isEmpty {
            contentBlocks.append(contentsOf: attachmentContentBlocks)
        }

        let userMessage: OpenAI.ChatMessageParam = .userMessage(
            OpenAI.MessageParam(
                role: "user",
                contentBlocks: contentBlocks
            )
        )

        // Create CueChatMessage and save to repository
        let cueChatMessage = CueChatMessage.openAI(userMessage, stableId: UUID().uuidString)
        addOrUpdateMessage(cueChatMessage)
        messageParams.append(cueChatMessage)

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
