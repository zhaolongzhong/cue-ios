import Foundation

public enum ChatModel: String, CaseIterable, Codable, Equatable, Hashable {
    case gpt4oMini = "gpt-4o-mini"
    case gpt4o = "gpt-4o"
    case gpt4_5 = "gpt-4.5-preview"
    case o3mini = "o3-mini"
    case o1 = "o1"
    case claude37Sonnet = "claude-3-7-sonnet-20250219"
    case claude35Sonnet = "claude-3-5-sonnet-20241022"
    case claude35Haiku = "claude-3-5-haiku-20241022"
    case gemini20FlashExp = "gemini-2.0-flash-exp"
    case gemini20Pro = "gemini-2.0-pro-exp-02-05"
    case deepSeekR17B = "deepseek-r1:7b"
    case llama323B = "llama3.2:latest"
    case qwen257B = "qwen2.5:7b"
    case qwen32B = "qwq:32b"

    var id: String {
        return self.rawValue
    }

    var displayName: String {
        switch self {
        case .gpt4oMini: return "GPT-4o mini"
        case .gpt4o: return "GPT-4o"
        case .gpt4_5: return "GPT-4.5"
        case .o3mini: return "o3 mini"
        case .o1: return "o1"
        case .claude37Sonnet: return "Claude 3.7 Sonnet"
        case .claude35Sonnet: return "Claude 3.5 Sonnet"
        case .claude35Haiku: return "Claude 3.5 Haiku"
        case .gemini20FlashExp: return "Gemini 2.0 Flash Exp"
        case .gemini20Pro: return "Gemini 2.0 Pro Exp"
        case .deepSeekR17B: return "Deep Seek R1 7B"
        case .llama323B: return "LLaMA 3.2 3B"
        case .qwen257B: return "Qwen 2.5 7B"
        case .qwen32B: return "Qwen 32B"
        }
    }

    var provider: Provider {
        switch self {
        case .gpt4oMini, .gpt4o, .gpt4_5, .o3mini, .o1:
            return .openai
        case .claude37Sonnet, .claude35Sonnet, .claude35Haiku:
            return .anthropic
        case .gemini20Pro, .gemini20FlashExp:
            return .gemini
        case .deepSeekR17B, .llama323B, .qwen257B, .qwen32B:
            return .local
        }
    }

    static func models(for provider: Provider) -> [ChatModel] {
        if provider == .cue {
            return [
                ChatModel.gpt4oMini,
                ChatModel.o3mini,
                ChatModel.o1,
                ChatModel.gpt4_5,
                ChatModel.claude35Sonnet,
                ChatModel.claude37Sonnet,
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

public extension ChatModel {
    init?(rawString: String) {
        self.init(rawValue: rawString)
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
