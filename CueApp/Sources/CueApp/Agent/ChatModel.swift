import Foundation

enum ChatModel: String, CaseIterable, Equatable, Hashable {
    case gpt4oMini = "gpt-4o-mini"
    case gpt4o = "gpt-4o"
    case o3mini = "o3-mini"
    case claude35Sonnet = "claude-3-5-sonnet-20241022"
    case claude35Haiku = "claude-3-5-haiku-20241022"
    case gemini20FlashExp = "gemini-2.0-flash-exp"
    case gemini20Pro = "gemini-2.0-pro-exp-02-05"

    var id: String {
        return self.rawValue
    }

    var displayName: String {
        switch self {
        case .gpt4oMini: return "GPT-4o mini"
        case .gpt4o: return "GPT-4o"
        case .o3mini: return "o3 mini"
        case .claude35Sonnet: return "Claude 3.5 Sonnet"
        case .claude35Haiku: return "Claude 3.5 Haiku"
        case .gemini20FlashExp: return "Gemini 2.0 Flash Exp"
        case .gemini20Pro: return "Gemini 2.0 Pro Exp"
        }
    }

    var provider: Provider {
        switch self {
        case .gpt4oMini, .gpt4o, .o3mini:
            return .openai
        case .claude35Sonnet, .claude35Haiku:
            return .anthropic
        case .gemini20Pro, .gemini20FlashExp:
            return .gemini
        }
    }

    static func models(for provider: Provider) -> [ChatModel] {
        if provider == .cue {
            return [
                ChatModel.gpt4oMini,
                ChatModel.o3mini,
                ChatModel.claude35Sonnet,
                ChatModel.gemini20FlashExp,
            ]
        }
        return Self.allCases.filter { $0.provider == provider }
    }
}

enum ChatRealtimeModel: String, CaseIterable {
    case gpt4oRealtimePreview = "gpt-4o-realtime-preview"
    case gpt4oMiniRealtimePreview = "gpt-4o-mini-realtime-preview"

    var id: String {
        return self.rawValue
    }

    var displayName: String {
        switch self {
        case .gpt4oRealtimePreview: return "GPT-4o Realtime Preview"
        case .gpt4oMiniRealtimePreview: return "GPT-4o Mini Realtime Preview"
        }
    }
}

enum ChatAudioModel: String, CaseIterable {
    case gpt4oAudioPreview = "gpt-4o-audio-preview"
    case gpt4oMiniAudioPreview = "gpt-4o-mini-audio-preview"

    var id: String {
        return self.rawValue
    }

    var displayName: String {
        switch self {
        case .gpt4oAudioPreview: return "GPT-4o Audio Preview"
        case .gpt4oMiniAudioPreview: return "GPT-4o Mini Audio Preview"
        }
    }
}
