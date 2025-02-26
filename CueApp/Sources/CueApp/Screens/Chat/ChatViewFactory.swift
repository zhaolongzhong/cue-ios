//
//  ChatViewFactory.swift
//  CueApp
//

import SwiftUI

struct ChatViewFactory {
    @MainActor static func createChatView(for provider: Provider, isCompanion: Bool = false, appDependencies: AppDependencies) -> AnyView {
        switch provider {
        case .gemini:
            return AnyView(GeminiChatView({ appDependencies.viewModelFactory.makeGeminiChatViewModel() }, isCompanion: isCompanion))
        case .anthropic:
            return AnyView(AnthropicChatView({ appDependencies.viewModelFactory.makeAnthropicChatViewModel() }, isCompanion: isCompanion))
        case .openai:
            return AnyView(OpenAIChatView({ appDependencies.viewModelFactory.makeOpenAIChatViewModel() }, isCompanion: isCompanion))
        case .local:
            return AnyView(LocalChatView({ appDependencies.viewModelFactory.makeLocalChatViewModel() }, isCompanion: isCompanion))
        case .cue:
            return AnyView(CueChatView({ appDependencies.viewModelFactory.makeCueChatViewModel() }, isCompanion: isCompanion))
        }
    }
}
