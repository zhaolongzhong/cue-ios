import Foundation

public enum ChatModel: String, CaseIterable, Codable, Equatable, Hashable {
    case gpt4oMini = "gpt-4o-mini"
    case gpt4o = "gpt-4o"
    case o3mini = "o3-mini"
    case claude35Sonnet = "claude-3-5-sonnet-20241022"
    case claude35Haiku = "claude-3-5-haiku-20241022"
    case gemini20FlashExp = "gemini-2.0-flash-exp"
    case gemini20Pro = "gemini-2.0-pro-exp-02-05"
    case deepSeekR17B = "deepseek-r1:7b"
    case llama323B = "llama3.2:latest"
    case qwen257B = "qwen2.5:7b"

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
        case .deepSeekR17B: return "Deep Seek R1 7B"
        case .llama323B: return "LLaMA 3.2 3B"
        case .qwen257B: return "Qwen 2.5 7B"
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
        case .deepSeekR17B, .llama323B, .qwen257B:
            return .local
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

    var isToolSupported: Bool {
        switch self {
        case .deepSeekR17B:
            return false
        default:
            return true
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
