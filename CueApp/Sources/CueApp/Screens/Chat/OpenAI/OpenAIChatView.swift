//
//  OpenAIChatView.swift
//  CueApp
//

import SwiftUI
import CueOpenAI

public struct OpenAIChatView: View {
    @StateObject private var viewModel: OpenAIChatViewModel
    @FocusState private var isFocused: Bool
    @State private var scrollThrottleWorkItem: DispatchWorkItem?
    @AppStorage(ProviderSettingsKeys.SelectedModel.openai) private var storedModel: ChatModel = .gpt4o
    @AppStorage(ProviderSettingsKeys.SelectedConversation.openai) private var storedConversationId: String?

    @State private var showingToolsList = false
    @State private var showingSidebar = false
    @State private var isHovering = false
    @State private var isShowingProviderDetails = false

    private let isCompanion: Bool

    public init(_ viewModelFactory: @escaping () -> OpenAIChatViewModel, isCompanion: Bool = false) {
        _viewModel = StateObject(wrappedValue: viewModelFactory())
        self.isCompanion = isCompanion
    }

    public var body: some View {
        BaseChatView(
            viewModel: viewModel,
            provider: .openai,
            availableModels: ChatModel.models(for: .openai),
            storedModel: $storedModel,
            isCompanion: isCompanion,
            showVoiceChat: true,
            showingSidebar: $showingSidebar,
            isHovering: $isHovering,
            scrollThrottleWorkItem: $scrollThrottleWorkItem,
            showingToolsList: $showingToolsList,
            isShowingProviderDetails: $isShowingProviderDetails,
            isStreamingEnabled: nil,
            isToolEnabled: nil,
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
            if storedConversationId == nil {
                await viewModel.loadConversations()
            }
            await viewModel.startServer()
        }
    }
}
