//
//  GeminiChatView.swift
//  CueApp
//

import SwiftUI
import CueGemini

public struct GeminiChatView: View {
    @StateObject private var viewModel: GeminiChatViewModel
    @FocusState private var isFocused: Bool
    @State private var scrollThrottleWorkItem: DispatchWorkItem?
    @AppStorage(ProviderSettingsKeys.SelectedModel.gemini) private var storedModel: ChatModel = .gemini20FlashExp
    @AppStorage(ProviderSettingsKeys.SelectedConversation.gemini) private var storedConversationId: String?

    @State private var showingToolsList = false
    @State private var showingSidebar = false
    @State private var isHovering = false
    @State private var isShowingProviderDetails = false

    private let isCompanion: Bool

    public init(_ viewModelFactory: @escaping () -> GeminiChatViewModel, isCompanion: Bool = false) {
        _viewModel = StateObject(wrappedValue: viewModelFactory())
        self.isCompanion = isCompanion
    }

    public var body: some View {
        BaseChatView(
            viewModel: viewModel,
            provider: .gemini,
            availableModels: ChatModel.models(for: .gemini),
            storedModel: $storedModel,
            isCompanion: isCompanion,
            showVoiceChat: true,
            showingSidebar: $showingSidebar,
            isHovering: $isHovering,
            scrollThrottleWorkItem: $scrollThrottleWorkItem,
            showingToolsList: $showingToolsList,
            isShowingProviderDetails: $isShowingProviderDetails,
            storedConversationId: storedConversationId,
            onAppear: { handleOnAppear() }
        )
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
