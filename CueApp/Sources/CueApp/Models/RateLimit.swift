import Foundation

struct ModelRateLimit: Codable {
    let model: String
    let requestLimit: Int
    let timeWindowHours: Int
    let requestCount: Int
    let windowStartTime: Date
    
    var isLimited: Bool {
        guard let windowEndTime = Calendar.current.date(
            byAdding: .hour,
            value: timeWindowHours,
            to: windowStartTime
        ) else {
            return false
        }
        
        return requestCount >= requestLimit && Date() < windowEndTime
    }
    
    var remainingRequests: Int {
        max(0, requestLimit - requestCount)
    }
    
    var timeUntilReset: TimeInterval? {
        guard let windowEndTime = Calendar.current.date(
            byAdding: .hour,
            value: timeWindowHours,
            to: windowStartTime
        ) else {
            return nil
        }
        
        let now = Date()
        guard now < windowEndTime else {
            return nil
        }
        
        return windowEndTime.timeIntervalSince(now)
    }
}

// Per-model rate limit configuration
struct RateLimitConfig: Codable {
    let model: String
    let requestLimit: Int
    let timeWindowHours: Int
    
    static let defaultConfigs: [String: RateLimitConfig] = [
        "gpt-4": RateLimitConfig(model: "gpt-4", requestLimit: 25, timeWindowHours: 24),
        "gpt-3.5-turbo": RateLimitConfig(model: "gpt-3.5-turbo", requestLimit: 50, timeWindowHours: 24),
        "claude-2.1": RateLimitConfig(model: "claude-2.1", requestLimit: 25, timeWindowHours: 24),
        "claude-instant-1.2": RateLimitConfig(model: "claude-instant-1.2", requestLimit: 50, timeWindowHours: 24),
        "default": RateLimitConfig(model: "default", requestLimit: 50, timeWindowHours: 24)
    ]
}

@MainActor
final class RateLimitManager {
    private let userDefaults: UserDefaults
    private let rateLimitKeyPrefix: String
    private var modelConfigs: [String: RateLimitConfig]
    
    init(
        userDefaults: UserDefaults = .standard,
        rateLimitKeyPrefix: String = "chat_rate_limit_",
        modelConfigs: [String: RateLimitConfig]? = nil
    ) {
        self.userDefaults = userDefaults
        self.rateLimitKeyPrefix = rateLimitKeyPrefix
        self.modelConfigs = modelConfigs ?? RateLimitConfig.defaultConfigs
    }
    
    private func rateLimitKey(for model: String) -> String {
        return rateLimitKeyPrefix + model
    }
    
    private func getConfig(for model: String) -> RateLimitConfig {
        return modelConfigs[model] ?? modelConfigs["default"]!
    }
    
    private func getCurrentRateLimit(for model: String) -> ModelRateLimit {
        let key = rateLimitKey(for: model)
        let config = getConfig(for: model)
        
        if let data = userDefaults.data(forKey: key),
           let rateLimit = try? JSONDecoder().decode(ModelRateLimit.self, from: data) {
            
            // Check if window has expired
            if let windowEndTime = Calendar.current.date(
                byAdding: .hour,
                value: rateLimit.timeWindowHours,
                to: rateLimit.windowStartTime
            ),
               Date() >= windowEndTime {
                // Window expired, create new window
                return ModelRateLimit(
                    model: model,
                    requestLimit: config.requestLimit,
                    timeWindowHours: config.timeWindowHours,
                    requestCount: 0,
                    windowStartTime: Date()
                )
            }
            
            return rateLimit
        }
        
        // No existing rate limit, create new one
        return ModelRateLimit(
            model: model,
            requestLimit: config.requestLimit,
            timeWindowHours: config.timeWindowHours,
            requestCount: 0,
            windowStartTime: Date()
        )
    }
    
    private func saveRateLimit(_ rateLimit: ModelRateLimit) {
        let key = rateLimitKey(for: rateLimit.model)
        if let data = try? JSONEncoder().encode(rateLimit) {
            userDefaults.set(data, forKey: key)
        }
    }
    
    func incrementRequestCount(for model: String) {
        var currentLimit = getCurrentRateLimit(for: model)
        currentLimit = ModelRateLimit(
            model: model,
            requestLimit: currentLimit.requestLimit,
            timeWindowHours: currentLimit.timeWindowHours,
            requestCount: currentLimit.requestCount + 1,
            windowStartTime: currentLimit.windowStartTime
        )
        saveRateLimit(currentLimit)
    }
    
    func checkRateLimit(for model: String) -> (isLimited: Bool, remainingRequests: Int, timeUntilReset: TimeInterval?) {
        let currentLimit = getCurrentRateLimit(for: model)
        return (
            isLimited: currentLimit.isLimited,
            remainingRequests: currentLimit.remainingRequests,
            timeUntilReset: currentLimit.timeUntilReset
        )
    }
    
    func resetRateLimit(for model: String) {
        let config = getConfig(for: model)
        let newLimit = ModelRateLimit(
            model: model,
            requestLimit: config.requestLimit,
            timeWindowHours: config.timeWindowHours,
            requestCount: 0,
            windowStartTime: Date()
        )
        saveRateLimit(newLimit)
    }
}