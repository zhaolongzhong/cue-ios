//
//  ChatViewFactory.swift
//  CueApp
//

import SwiftUI

struct ChatViewFactory {
    @MainActor static func createChatView(conversationId: String, provider: Provider, isCompanion: Bool = false, appDependencies: AppDependencies) -> SingleChatView {
        switch provider {
        case .openai:
//            return AnyView(OpenAIChatView(appDependencies.viewModelFactory.makeOpenAIChatViewModel, conversationId: conversationId, isCompanion: isCompanion))
            return SingleChatView(conversationId: conversationId, provider: .openai, isCompanion: isCompanion, dependencies: appDependencies)
//        case .gemini:
//            return AnyView(GeminiChatView(appDependencies.viewModelFactory.makeGeminiChatViewModel, conversationId: conversationId, isCompanion: isCompanion))
//        case .anthropic:
//            return AnyView(AnthropicChatView(appDependencies.viewModelFactory.makeAnthropicChatViewModel, isCompanion: isCompanion))
//
//        case .local:
//            return AnyView(LocalChatView(appDependencies.viewModelFactory.makeLocalChatViewModel, conversationId: conversationId, isCompanion: isCompanion))
//        case .cue:
//            return AnyView(CueChatView(appDependencies.viewModelFactory.makeCueChatViewModel, conversationId: conversationId, isCompanion: isCompanion))
        default:
//            return AnyView(OpenAIChatView(appDependencies.viewModelFactory.makeOpenAIChatViewModel, conversationId: conversationId, isCompanion: isCompanion))
            return SingleChatView(conversationId: conversationId, provider: .openai, isCompanion: isCompanion, dependencies: appDependencies)
        }
    }
}
