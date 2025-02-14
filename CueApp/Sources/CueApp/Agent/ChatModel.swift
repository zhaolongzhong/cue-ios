enum ChatModel: String, CaseIterable {
    case gpt4oMini = "gpt-4o-mini"
    case o3Mini = "o3-mini"
    case claude35Sonnet = "claude-3-5-sonnet-20241022"
    case claude35Haiku = "claude-3-5-haiku-20241022"
    case gemini20Pro = "gemini-2.0-pro-exp-02-05"
    case gemini20Flash = "gemini-2.0-flash-001"

    var id: String {
        return self.rawValue
    }

    var displayName: String {
        switch self {
        case .gpt4oMini: return "GPT-4o Mini"
        case .o3Mini: return "O3 Mini"
        case .claude35Sonnet: return "Claude 3.5 Sonnet"
        case .claude35Haiku: return "Claude 3.5 Haiku"
        case .gemini20Pro: return "Gemini 2.0 Pro"
        case .gemini20Flash: return "Gemini 2.0 Flash"
        }
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
