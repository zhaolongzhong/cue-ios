//
//  GeminiChatView.swift
//  CueApp
//

import SwiftUI
import CueGemini

public struct GeminiChatView: View {
    @StateObject private var viewModel: GeminiChatViewModel
    @AppStorage(ProviderSettingsKeys.SelectedModel.gemini) private var storedModel: ChatModel = .gemini20FlashExp
    @AppStorage(ProviderSettingsKeys.SelectedConversation.gemini) private var storedConversationId: String?

    private let isCompanion: Bool

    public init(_ viewModelFactory: @escaping (String?) -> GeminiChatViewModel, conversationId: String? = nil, isCompanion: Bool = false) {
        _viewModel = StateObject(wrappedValue: viewModelFactory(conversationId))
        self.isCompanion = isCompanion
    }

    public var body: some View {
        BaseChatView(
            viewModel: viewModel,
            provider: .gemini,
            availableModels: ChatModel.models(for: .gemini),
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
            await viewModel.startServer()
        }
    }
}
