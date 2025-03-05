//
//  OpenAIChatView.swift
//  CueApp
//

import SwiftUI
import CueOpenAI

public struct OpenAIChatView: View {
    @StateObject private var viewModel: OpenAIChatViewModel
    @AppStorage(ProviderSettingsKeys.SelectedModel.openai) private var storedModel: ChatModel = .gpt4o
    @AppStorage(ProviderSettingsKeys.SelectedConversation.openai) private var storedConversationId: String?

    private let isCompanion: Bool

    public init(_ viewModelFactory: @escaping (String?) -> OpenAIChatViewModel, conversationId: String? = nil, isCompanion: Bool = false) {
        _viewModel = StateObject(wrappedValue: viewModelFactory(conversationId))
        self.isCompanion = isCompanion
    }

    public var body: some View {
        BaseChatView(
            viewModel: viewModel,
            provider: .openai,
            availableModels: ChatModel.models(for: .openai),
            storedModel: $storedModel,
            storedConversationId: storedConversationId,
            chatViewState: ChatViewState(isCompanion: isCompanion, isStreamingEnabled: true, isToolEnabled: true)
        )
        .onAppear { handleOnAppear() }
        .onChange(of: viewModel.selectedConversationId) { _, newId in
            if let newId = newId {
                storedConversationId = newId
            }
        }
    }

    private func handleOnAppear() {
        viewModel.model = storedModel
        viewModel.setStoredConversationId(storedConversationId)

        Task {
            if storedConversationId == nil {
                await viewModel.loadConversations()
            }
            await viewModel.startServer()
        }
    }
}
