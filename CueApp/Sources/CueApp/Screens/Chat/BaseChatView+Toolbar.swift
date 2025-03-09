//
//  BaseChatView.swift
//  CueApp
//

import SwiftUI
import CueOpenAI

// MARK: - Navigation and Actions

extension BaseChatView {
    // MARK: Toolbar
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ModelSelectorToolbar(
            currentModel: viewModel.model,
            models: ChatModel.models(for: provider),
            iconView: AnyView(Provider.local.iconView),
            getModelName: { $0.displayName },
            onModelSelected: { model in
                storedModel.wrappedValue = model
                viewModel.model = model
            },
            isStreamingEnabled: $viewModel.isStreamingEnabled,
            isToolEnabled: $viewModel.isToolEnabled
        )
    }

    #if os(macOS)
    @ToolbarContentBuilder
    var macToolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Spacer()
            Button {
                createNewConversation()
            } label: {
                Image(systemName: "square.and.pencil")
                    .modifier(ToolbarIconStyle())
                    .foregroundStyle(.primary)
            }
            .help("Create New Session")
            Button {
                withAnimation(.easeInOut) {
                    $chatViewState.showingSidebar.wrappedValue.toggle()
                }
            } label: {
                Image(systemName: "list.bullet")
                    .modifier(ToolbarIconStyle())
                    .foregroundStyle(.primary)
            }
            .help("Open Sessions")
            Menu {
                Button("Open companion chat") {
                    openCompanionChat(isLive: false)
                }
                Button("Provider Details") {
                    $chatViewState.isShowingProviderDetails.wrappedValue = true
                }
                Button("Clear Messages") {
                    if let localVM = viewModel as? LocalChatViewModel {
                       localVM.resetMessages()
                   }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .modifier(ToolbarIconStyle())
                    .foregroundStyle(.primary)
            }
            .help("More Options")
            .menuIndicator(.hidden)
        }
    }
    #endif
}

//
//  BaseChatView.swift
//  CueApp
//

import SwiftUI
import CueOpenAI

// MARK: - Navigation and Actions

extension SingleChatView {
    // MARK: Toolbar
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ModelSelectorToolbar(
            currentModel: viewModel.model,
            models: ChatModel.models(for: provider),
            iconView: AnyView(Provider.local.iconView),
            getModelName: { $0.displayName },
            onModelSelected: { model in
//                storedModel.wrappedValue = model
                viewModel.model = model
            },
            isStreamingEnabled: $viewModel.isStreamingEnabled,
            isToolEnabled: $viewModel.isToolEnabled
        )
    }

    #if os(macOS)
    @ToolbarContentBuilder
    var macToolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Spacer()
            Button {
                createNewConversation()
            } label: {
                Image(systemName: "square.and.pencil")
                    .modifier(ToolbarIconStyle())
                    .foregroundStyle(.primary)
            }
            .help("Create New Session")
            Button {
                withAnimation(.easeInOut) {
//                    $chatViewState.showingSidebar.wrappedValue.toggle()
                }
            } label: {
                Image(systemName: "list.bullet")
                    .modifier(ToolbarIconStyle())
                    .foregroundStyle(.primary)
            }
            .help("Open Sessions")
            Menu {
                Button("Open companion chat") {
                    openCompanionChat(isLive: false)
                }
                Button("Provider Details") {
//                    $chatViewState.isShowingProviderDetails.wrappedValue = true
                }
                Button("Clear Messages") {
                    if let localVM = viewModel as? LocalChatViewModel {
                       localVM.resetMessages()
                   }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .modifier(ToolbarIconStyle())
                    .foregroundStyle(.primary)
            }
            .help("More Options")
            .menuIndicator(.hidden)
        }
    }
    #endif
}
