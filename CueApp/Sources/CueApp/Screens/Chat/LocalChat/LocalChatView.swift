//
//  LocalChatView.swift
//  CueApp
//

import SwiftUI
import CueOpenAI

public struct LocalChatView: View {
    @StateObject private var viewModel: LocalChatViewModel
    @AppStorage(ProviderSettingsKeys.SelectedModel.local) private var storedModel: ChatModel = .deepSeekR17B
    @AppStorage(ProviderSettingsKeys.SelectedConversation.local) private var storedConversationId: String?

    @AppStorage(ProviderSettingsKeys.MaxMessage.local) private var maxMessages = 20
    @AppStorage(ProviderSettingsKeys.MaxTurns.local) private var maxTurns = 20
    @AppStorage(ProviderSettingsKeys.Streaming.local) private var storedStreamingEnabled: Bool = true
    @AppStorage(ProviderSettingsKeys.ToolEnabled.local) private var storedToolEnabled: Bool = true
    @AppStorage(ProviderSettingsKeys.BaseURL.local) private var storedBaseURL: String?

    private let isCompanion: Bool

    public init(_ viewModelFactory: @escaping (String?) -> LocalChatViewModel, conversationId: String? = nil, isCompanion: Bool = false) {
        _viewModel = StateObject(wrappedValue: viewModelFactory(conversationId))
        self.isCompanion = isCompanion
    }

    public var body: some View {
        BaseChatView(
            viewModel: viewModel,
            provider: .local,
            availableModels: ChatModel.models(for: .local),
            storedModel: $storedModel,
            isStreamingEnabled: $viewModel.isStreamingEnabled,
            isToolEnabled: $viewModel.isToolEnabled,
            onReloadProviderSettings: {
                reloadProviderSettings()
            }
        )
        .onAppear { handleOnAppear() }
        .onChange(of: viewModel.selectedConversationId) { _, newId in
            if let newId = newId {
                storedConversationId = newId
            }
        }
        .onChange(of: viewModel.isStreamingEnabled) { _, newValue in
            storedStreamingEnabled = newValue
        }
        .onChange(of: viewModel.isToolEnabled) { _, newValue in
            storedToolEnabled = newValue
        }
    }

    private func handleOnAppear() {
        viewModel.model = storedModel
        viewModel.setStoredConversationId(storedConversationId)
        viewModel.isStreamingEnabled = storedStreamingEnabled
        viewModel.isToolEnabled = storedToolEnabled

        // Set the base URL if available, otherwise use default
        if let baseURL = storedBaseURL, !baseURL.isEmpty {
            viewModel.baseURL = baseURL
        } else {
            viewModel.baseURL = UserDefaults.standard.baseURLWithDefault(for: .local)
        }

        Task {
            await viewModel.startServer()
        }
    }

    private func reloadProviderSettings() {
        viewModel.maxMessages = maxMessages
        viewModel.maxTurns = maxTurns
        viewModel.isStreamingEnabled = storedStreamingEnabled
        viewModel.isToolEnabled = storedToolEnabled

        if let baseURL = storedBaseURL, !baseURL.isEmpty {
            viewModel.baseURL = baseURL
        } else {
            viewModel.baseURL = UserDefaults.standard.baseURLWithDefault(for: .local)
        }
    }
}
