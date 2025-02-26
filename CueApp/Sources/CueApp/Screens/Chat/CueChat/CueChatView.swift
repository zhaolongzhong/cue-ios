//
//  CueChatView.swift
//  CueApp
//

import SwiftUI

public struct CueChatView: View {
    @StateObject private var viewModel: CueChatViewModel
    @FocusState private var isFocused: Bool
    @State private var scrollThrottleWorkItem: DispatchWorkItem?
    @AppStorage(ProviderSettingsKeys.SelectedModel.openai) private var storedModel: ChatModel = .gpt4oMini
    @AppStorage(ProviderSettingsKeys.SelectedConversation.openai) private var storedConversationId: String?

    @State private var showingToolsList = false
    @State private var showingSidebar = false
    @State private var isHovering = false
    @State private var isShowingProviderDetails = false

    private let isCompanion: Bool

    public init(_ viewModelFactory: @escaping () -> CueChatViewModel, isCompanion: Bool = false) {
        _viewModel = StateObject(wrappedValue: viewModelFactory())
        self.isCompanion = isCompanion
    }

    public var body: some View {
        BaseChatView(
            viewModel: viewModel,
            provider: .cue,
            availableModels: ChatModel.models(for: .cue),
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
