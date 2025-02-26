import Foundation

/// Provides type-safe constants for provider settings
public enum ProviderSettingsKeys {
    /// Keys for max messages settings
    public enum MaxMessage {
        public static let local = "local_chat_max_message"
        public static let openai = "openai_chat_max_message"
        public static let anthropic = "anthropic_chat_max_message"
        public static let gemini = "gemini_chat_max_message"
        public static let cue = "cue_chat_max_message"

        /// Gets the appropriate max turn key for a provider
        public static func key(for provider: Provider) -> String {
            switch provider {
            case .local: return local
            case .openai: return openai
            case .anthropic: return anthropic
            case .gemini: return gemini
            case .cue: return cue
            }
        }
    }

    /// Keys for max turns settings
    public enum MaxTurns {
        public static let local = "local_chat_max_turn"
        public static let openai = "openai_chat_max_turn"
        public static let anthropic = "anthropic_chat_max_turn"
        public static let gemini = "gemini_chat_max_turn"
        public static let cue = "cue_chat_max_turn"

        /// Gets the appropriate max turn key for a provider
        public static func key(for provider: Provider) -> String {
            switch provider {
            case .local: return local
            case .openai: return openai
            case .anthropic: return anthropic
            case .gemini: return gemini
            case .cue: return cue
            }
        }
    }

    /// Keys for streaming settings
    public enum Streaming {
        public static let local = "isLocalChatStreamingEnabled"
        public static let openai = "isOpenAIChatStreamingEnabled"
        public static let anthropic = "isAnthropicChatStreamingEnabled"
        public static let gemini = "isGeminiChatStreamingEnabled"
        public static let cue = "isCueChatStreamingEnabled"

        /// Gets the appropriate streaming key for a provider
        public static func key(for provider: Provider) -> String {
            switch provider {
            case .local: return local
            case .openai: return openai
            case .anthropic: return anthropic
            case .gemini: return gemini
            case .cue: return cue
            }
        }
    }

    /// Keys for tool enablement settings
    public enum ToolEnabled {
        public static let local = "isLocalChatToolEnabled"
        public static let openai = "isOpenAIChatToolEnabled"
        public static let anthropic = "isAnthropicChatToolEnabled"
        public static let gemini = "isGeminiChatToolEnabled"
        public static let cue = "isCueChatToolEnabled"

        /// Gets the appropriate tool enabled key for a provider
        public static func key(for provider: Provider) -> String {
            switch provider {
            case .local: return local
            case .openai: return openai
            case .anthropic: return anthropic
            case .gemini: return gemini
            case .cue: return cue
            }
        }
    }

    /// Keys for API keys
    public enum APIKey {
        public static let openai = "openai_api_key"
        public static let anthropic = "anthropic_api_key"
        public static let gemini = "gemini_api_key"
        public static let cue = "cue_api_key"

        /// Gets the appropriate API key for a provider
        public static func key(for provider: Provider) -> String? {
            switch provider {
            case .local: return nil // Local doesn't use API key
            case .openai: return openai
            case .anthropic: return anthropic
            case .gemini: return gemini
            case .cue: return cue
            }
        }
    }

    /// Keys for selected model
    public enum SelectedModel {
        public static let local = "selectedLocalModel"
        public static let openai = "selectedOpenAIModel"
        public static let anthropic = "selectedAnthropicModel"
        public static let gemini = "selectedGeminiModel"
        public static let cue = "selectedCueModel"

        /// Gets the appropriate selected model key for a provider
        public static func key(for provider: Provider) -> String {
            switch provider {
            case .local: return local
            case .openai: return openai
            case .anthropic: return anthropic
            case .gemini: return gemini
            case .cue: return cue
            }
        }
    }

    /// Keys for selected conversationId
    public enum SelectedConversation {
        public static let local = "selectedLocalConversation"
        public static let openai = "selectedOpenAIConversation"
        public static let anthropic = "selectedAnthropicConversation"
        public static let gemini = "selectedGeminiConversation"
        public static let cue = "selectedCueConversation"

        /// Gets the appropriate selected model key for a provider
        public static func key(for provider: Provider) -> String {
            switch provider {
            case .local: return local
            case .openai: return openai
            case .anthropic: return anthropic
            case .gemini: return gemini
            case .cue: return cue
            }
        }
    }

    public enum BaseURL {
        public static let local = "local_base_url"
        public static let openai = "openai_base_url"
        public static let anthropic = "anthropic_base_url"
        public static let gemini = "gemini_base_url"
        public static let cue = "cue_base_url"

        /// Gets the appropriate base URL key for a provider
        public static func key(for provider: Provider) -> String {
            switch provider {
            case .local: return local
            case .openai: return openai
            case .anthropic: return anthropic
            case .gemini: return gemini
            case .cue: return cue
            }
        }
    }
}

// Extension to UserDefaults to provide type-safe access
extension UserDefaults {
    // Max Turns methods
    func maxMessages(for provider: Provider) -> Int {
        let value = integer(forKey: ProviderSettingsKeys.MaxTurns.key(for: provider))
        return value > 0 ? value : 20 // Default is 20 if not set
    }

    func setMaxMessages(_ value: Int, for provider: Provider) {
        set(value, forKey: ProviderSettingsKeys.MaxTurns.key(for: provider))
    }

    // Max Turns methods
    func maxTurns(for provider: Provider) -> Int {
        let value = integer(forKey: ProviderSettingsKeys.MaxTurns.key(for: provider))
        return value > 0 ? value : 20 // Default is 20 if not set
    }

    func setMaxTurns(_ value: Int, for provider: Provider) {
        set(value, forKey: ProviderSettingsKeys.MaxTurns.key(for: provider))
    }

    // Streaming methods
    func isStreamingEnabled(for provider: Provider) -> Bool {
        bool(forKey: ProviderSettingsKeys.Streaming.key(for: provider))
    }

    func setStreamingEnabled(_ value: Bool, for provider: Provider) {
        set(value, forKey: ProviderSettingsKeys.Streaming.key(for: provider))
    }

    // Tool enabled methods
    func isToolEnabled(for provider: Provider) -> Bool {
        bool(forKey: ProviderSettingsKeys.ToolEnabled.key(for: provider))
    }

    func setToolEnabled(_ value: Bool, for provider: Provider) {
        set(value, forKey: ProviderSettingsKeys.ToolEnabled.key(for: provider))
    }

    // API Key methods
    func apiKey(for provider: Provider) -> String? {
        guard let key = ProviderSettingsKeys.APIKey.key(for: provider) else {
            return nil // Provider doesn't use API key
        }
        return string(forKey: key)
    }

    func setAPIKey(_ value: String?, for provider: Provider) {
        guard let key = ProviderSettingsKeys.APIKey.key(for: provider) else {
            return // Provider doesn't use API key
        }
        set(value, forKey: key)
    }

    func hasAPIKey(for provider: Provider) -> Bool {
        guard let key = ProviderSettingsKeys.APIKey.key(for: provider) else {
            return true // Provider doesn't need API key
        }
        return !(string(forKey: key).isNilOrEmpty)
    }
}

extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool {
        return self == nil || self == ""
    }
}

extension UserDefaults {
    // Base URL methods
    func baseURL(for provider: Provider) -> String? {
        return string(forKey: ProviderSettingsKeys.BaseURL.key(for: provider))
    }

    func setBaseURL(_ value: String?, for provider: Provider) {
        set(value, forKey: ProviderSettingsKeys.BaseURL.key(for: provider))
    }

    func baseURLWithDefault(for provider: Provider) -> String {
        if let storedURL = baseURL(for: provider), !storedURL.isEmpty {
            return storedURL
        }

        // Return default URLs for each provider
        switch provider {
        case .local:
            return "http://localhost:8080"
        case .openai:
            return "https://api.openai.com"
        case .anthropic:
            return "https://api.anthropic.com"
        case .gemini:
            return "https://generativelanguage.googleapis.com"
        default:
            return ""
        }
    }
}
