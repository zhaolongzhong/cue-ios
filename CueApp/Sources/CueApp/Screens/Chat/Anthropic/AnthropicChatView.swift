//
//  AnthropicChatView.swift
//  CueApp
//

import SwiftUI
import CueAnthropic

public struct AnthropicChatView: View {
    @StateObject private var viewModel: AnthropicChatViewModel
    @AppStorage(ProviderSettingsKeys.SelectedModel.anthropic) private var storedModel: ChatModel = .claude37Sonnet
    @AppStorage(ProviderSettingsKeys.SelectedConversation.anthropic) private var storedConversationId: String?

    private let isCompanion: Bool

    public init(_ viewModelFactory: @escaping (String?) -> AnthropicChatViewModel, conversationId: String? = nil, isCompanion: Bool = false) {
        _viewModel = StateObject(wrappedValue: viewModelFactory(conversationId))
        self.isCompanion = isCompanion
    }

    public var body: some View {
        BaseChatView(
            viewModel: viewModel,
            provider: .anthropic,
            availableModels: ChatModel.models(for: .anthropic),
            storedModel: $storedModel,
            storedConversationId: storedConversationId
        )
        .onAppear { handleOnAppear() }
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
