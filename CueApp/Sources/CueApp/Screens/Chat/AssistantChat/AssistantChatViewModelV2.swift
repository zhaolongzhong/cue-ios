//
//  CueChatViewModel.swift
//  CueApp
//

import Foundation
import CueCommon
import CueOpenAI
import CueAnthropic
import Dependencies

@MainActor
public final class AssistantChatViewModelV2: BaseChatViewModel {
    @Dependency(\.assistantRepository) private var assistantRepository
    @Published var showAssistantDetails = false
    private let cueClient: CueClient
    private var conversation: ConversationModel?
    @Published var assistant: Assistant

    public init(assistant: Assistant, conversationId: String) {
        self.cueClient = CueClient()
        self.assistant = assistant
        var model = ChatModel.gpt4oMini
        if let modelId = assistant.metadata?.model, let chatModel = ChatModel.init(rawValue: modelId) {
            model = chatModel
        }

        super.init(
            apiKey: "",
            provider: .cue,
            model: model,
            conversationId: conversationId,
            richTextFieldState: RichTextFieldState(showToolIcon: true),
            enabledTools: [],
            enableRemote: true
        )

        Task {
            self.conversation = await fetchAssistantConversation(id: assistant.id)
            self.conversationId = self.conversation?.id ?? ""
        }
    }

    override func sendMessage() async {
        let (userMessage, _) = await prepareOpenAIMessage()

        // Add user message to chat
        let cueChatMessage = CueChatMessage.openAI(userMessage, stableId: UUID().uuidString)
        addOrUpdateMessage(cueChatMessage, persistInCache: true, enableRemote: true)

        // Get updated message list including the newly added message
        let messageParams = Array(self.cueChatMessages.suffix(maxMessages)).map { $0.toMessageParam(simple: true) }

        isLoading = true
        richTextFieldState = richTextFieldState.copy(inputMessage: "")

        do {
            let agent = AgentLoop(chatClient: cueClient, toolManager: toolManager, model: model.rawValue)
            let completionRequest = CompletionRequest(model: model.rawValue, tools: tools, toolChoice: "auto")
            let updatedMessages = try await agent.run(with: messageParams, request: completionRequest)

            for message in updatedMessages {
                addOrUpdateMessage(message, persistInCache: true, enableRemote: true)
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

extension AssistantChatViewModelV2 {
    private func fetchAssistantConversation(id: String) async -> ConversationModel? {
        guard !id.isEmpty else {
            AppLog.log.error("fetchAssistantConversation id is empty")
            return nil
        }
        switch await assistantRepository.listAssistantConversations(id: id, isPrimary: true, skip: 0, limit: 20) {
        case .success(let conversations):
            if conversations.isEmpty {
                return await createPrimaryAssistant()
            } else {
                return conversations[0]
            }

        case .failure(let error):
            handleError(error)
            return nil
        }
    }

    private func createPrimaryAssistant() async -> ConversationModel? {
        switch await assistantRepository.createPrimaryConversation(assistantId: assistant.id, name: nil) {
        case .success(let conversation):
            return conversation

        case .failure(let error):
            handleError(error)
            return nil
        }
    }
}
