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
    
    /// Keys for request limit settings
    public enum RequestLimit {
        public static let local = "local_request_limit"
        public static let openai = "openai_request_limit"
        public static let anthropic = "anthropic_request_limit"
        public static let gemini = "gemini_request_limit"
        public static let cue = "cue_request_limit"
        
        /// Gets the appropriate request limit key for a provider
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
    
    /// Keys for request limit time window settings (in hours)
    public enum RequestLimitWindow {
        public static let local = "local_request_limit_window"
        public static let openai = "openai_request_limit_window"
        public static let anthropic = "anthropic_request_limit_window"
        public static let gemini = "gemini_request_limit_window"
        public static let cue = "cue_request_limit_window"
        
        /// Gets the appropriate request limit window key for a provider
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
    
    /// Keys for request limit timestamp
    public enum RequestLimitTimestamp {
        public static let local = "local_request_limit_timestamp"
        public static let openai = "openai_request_limit_timestamp"
        public static let anthropic = "anthropic_request_limit_timestamp"
        public static let gemini = "gemini_request_limit_timestamp"
        public static let cue = "cue_request_limit_timestamp"
        
        /// Gets the appropriate request limit timestamp key for a provider
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
    
    /// Keys for request count
    public enum RequestCount {
        public static let local = "local_request_count"
        public static let openai = "openai_request_count"
        public static let anthropic = "anthropic_request_count"
        public static let gemini = "gemini_request_count"
        public static let cue = "cue_request_count"
        
        /// Gets the appropriate request count key for a provider
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
    
    // Request limit methods
    func requestLimit(for provider: Provider) -> Int {
        let value = integer(forKey: ProviderSettingsKeys.RequestLimit.key(for: provider))
        return value > 0 ? value : 50 // Default is 50 if not set
    }
    
    func setRequestLimit(_ value: Int, for provider: Provider) {
        set(value, forKey: ProviderSettingsKeys.RequestLimit.key(for: provider))
    }
    
    // Request limit window methods (in hours)
    func requestLimitWindow(for provider: Provider) -> Int {
        let value = integer(forKey: ProviderSettingsKeys.RequestLimitWindow.key(for: provider))
        return value > 0 ? value : 24 // Default is 24 hours if not set
    }
    
    func setRequestLimitWindow(_ value: Int, for provider: Provider) {
        set(value, forKey: ProviderSettingsKeys.RequestLimitWindow.key(for: provider))
    }
    
    // Request count and timestamp methods
    func requestCount(for provider: Provider) -> Int {
        return integer(forKey: ProviderSettingsKeys.RequestCount.key(for: provider))
    }
    
    func setRequestCount(_ value: Int, for provider: Provider) {
        set(value, forKey: ProviderSettingsKeys.RequestCount.key(for: provider))
    }
    
    func requestLimitTimestamp(for provider: Provider) -> Date? {
        return object(forKey: ProviderSettingsKeys.RequestLimitTimestamp.key(for: provider)) as? Date
    }
    
    func setRequestLimitTimestamp(_ date: Date, for provider: Provider) {
        set(date, forKey: ProviderSettingsKeys.RequestLimitTimestamp.key(for: provider))
    }
    
    // Function to check if request limit is reached
    func isRequestLimitReached(for provider: Provider) -> Bool {
        let limit = requestLimit(for: provider)
        
        // If limit is 0, there's no limit
        if limit == 0 {
            return false
        }
        
        let currentCount = requestCount(for: provider)
        let windowHours = requestLimitWindow(for: provider)
        
        // If we haven't reached the limit yet, we're good
        if currentCount < limit {
            return false
        }
        
        // Check if we're still within the time window
        if let timestamp = requestLimitTimestamp(for: provider) {
            let windowSeconds = Double(windowHours * 3600)
            let elapsedTime = Date().timeIntervalSince(timestamp)
            
            // If we're still within the time window, the limit is reached
            if elapsedTime < windowSeconds {
                return true
            } else {
                // Time window has passed, reset counters
                resetRequestCounters(for: provider)
                return false
            }
        } else {
            // No timestamp, reset counters
            resetRequestCounters(for: provider)
            return false
        }
    }
    
    // Function to increment request count
    func incrementRequestCount(for provider: Provider) {
        let currentCount = requestCount(for: provider)
        let limit = requestLimit(for: provider)
        
        // If limit is 0, there's no limit, so don't increment
        if limit == 0 {
            return
        }
        
        // If this is the first request or we're starting a new window, set the timestamp
        if currentCount == 0 {
            setRequestLimitTimestamp(Date(), for: provider)
        }
        
        setRequestCount(currentCount + 1, for: provider)
    }
    
    // Function to reset request counters
    func resetRequestCounters(for provider: Provider) {
        setRequestCount(0, for: provider)
        setRequestLimitTimestamp(Date(), for: provider)
    }
}
