//
//  AnthropicChatView.swift
//  CueApp
//

import SwiftUI
import CueAnthropic

public struct AnthropicChatView: View {
    @StateObject private var viewModel: AnthropicChatViewModel
    @FocusState private var isFocused: Bool
    @State private var scrollThrottleWorkItem: DispatchWorkItem?
    @AppStorage(ProviderSettingsKeys.SelectedModel.anthropic) private var storedModel: ChatModel = .claude37Sonnet
    @AppStorage(ProviderSettingsKeys.SelectedConversation.anthropic) private var storedConversationId: String?

    @State private var showingToolsList = false
    @State private var showingSidebar = false
    @State private var isHovering = false
    @State private var isShowingProviderDetails = false

    private let isCompanion: Bool

    public init(_ viewModelFactory: @escaping () -> AnthropicChatViewModel, isCompanion: Bool = false) {
        _viewModel = StateObject(wrappedValue: viewModelFactory())
        self.isCompanion = isCompanion
    }

    public var body: some View {
        BaseChatView(
            viewModel: viewModel,
            provider: .anthropic,
            availableModels: ChatModel.models(for: .anthropic),
            storedModel: $storedModel,
            isCompanion: isCompanion,
            showVoiceChat: false,
            showingSidebar: $showingSidebar,
            isHovering: $isHovering,
            scrollThrottleWorkItem: $scrollThrottleWorkItem,
            showingToolsList: $showingToolsList,
            isShowingProviderDetails: $isShowingProviderDetails,
            storedConversationId: storedConversationId,
            onAppear: { handleOnAppear() }
        )
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
