//
//  CueChatView.swift
//  CueApp
//

import SwiftUI

public struct CueChatView: View {
    @StateObject private var viewModel: CueChatViewModel
    @FocusState private var isFocused: Bool
    @AppStorage(ProviderSettingsKeys.SelectedModel.openai) private var storedModel: ChatModel = .gpt4oMini
    @AppStorage(ProviderSettingsKeys.SelectedConversation.openai) private var storedConversationId: String?

    private let isCompanion: Bool

    public init(_ viewModelFactory: @escaping (String?) -> CueChatViewModel, conversationId: String? = nil, isCompanion: Bool = false) {
        _viewModel = StateObject(wrappedValue: viewModelFactory(conversationId))
        self.isCompanion = isCompanion
    }

    public var body: some View {
        BaseChatView(
            viewModel: viewModel,
            provider: .cue,
            availableModels: ChatModel.models(for: .cue),
            storedModel: $storedModel,
            storedConversationId: storedConversationId
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
