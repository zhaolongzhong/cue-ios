//
//  ChatViewFactory.swift
//  CueApp
//

import SwiftUI

struct ChatViewFactory {
    @MainActor static func createChatView(conversationId: String? = nil, provider: Provider, isCompanion: Bool = false, appDependencies: AppDependencies) -> AnyView {
        switch provider {
        case .gemini:
            return AnyView(GeminiChatView(appDependencies.viewModelFactory.makeGeminiChatViewModel, conversationId: conversationId, isCompanion: isCompanion))
        case .anthropic:
            return AnyView(AnthropicChatView(appDependencies.viewModelFactory.makeAnthropicChatViewModel, isCompanion: isCompanion))
        case .openai:
            return AnyView(OpenAIChatView(appDependencies.viewModelFactory.makeOpenAIChatViewModel, conversationId: conversationId, isCompanion: isCompanion))
        case .local:
            return AnyView(LocalChatView(appDependencies.viewModelFactory.makeLocalChatViewModel, conversationId: conversationId, isCompanion: isCompanion))
        case .cue:
            return AnyView(CueChatView(appDependencies.viewModelFactory.makeCueChatViewModel, conversationId: conversationId, isCompanion: isCompanion))
        }
    }
}
