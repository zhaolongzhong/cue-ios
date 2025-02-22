import Foundation

struct RateLimit: Codable {
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

@MainActor
final class RateLimitManager {
    private let userDefaults: UserDefaults
    private let defaultLimit: Int
    private let defaultTimeWindow: Int
    private let rateLimitKey: String
    
    init(
        userDefaults: UserDefaults = .standard,
        defaultLimit: Int = 50,
        defaultTimeWindow: Int = 24,
        rateLimitKey: String = "chat_rate_limit"
    ) {
        self.userDefaults = userDefaults
        self.defaultLimit = defaultLimit
        self.defaultTimeWindow = defaultTimeWindow
        self.rateLimitKey = rateLimitKey
    }
    
    private func getCurrentRateLimit() -> RateLimit {
        if let data = userDefaults.data(forKey: rateLimitKey),
           let rateLimit = try? JSONDecoder().decode(RateLimit.self, from: data) {
            
            // Check if window has expired
            if let windowEndTime = Calendar.current.date(
                byAdding: .hour,
                value: rateLimit.timeWindowHours,
                to: rateLimit.windowStartTime
            ),
               Date() >= windowEndTime {
                // Window expired, create new window
                return RateLimit(
                    requestLimit: defaultLimit,
                    timeWindowHours: defaultTimeWindow,
                    requestCount: 0,
                    windowStartTime: Date()
                )
            }
            
            return rateLimit
        }
        
        // No existing rate limit, create new one
        return RateLimit(
            requestLimit: defaultLimit,
            timeWindowHours: defaultTimeWindow,
            requestCount: 0,
            windowStartTime: Date()
        )
    }
    
    private func saveRateLimit(_ rateLimit: RateLimit) {
        if let data = try? JSONEncoder().encode(rateLimit) {
            userDefaults.set(data, forKey: rateLimitKey)
        }
    }
    
    func incrementRequestCount() {
        var currentLimit = getCurrentRateLimit()
        currentLimit = RateLimit(
            requestLimit: currentLimit.requestLimit,
            timeWindowHours: currentLimit.timeWindowHours,
            requestCount: currentLimit.requestCount + 1,
            windowStartTime: currentLimit.windowStartTime
        )
        saveRateLimit(currentLimit)
    }
    
    func checkRateLimit() -> (isLimited: Bool, remainingRequests: Int, timeUntilReset: TimeInterval?) {
        let currentLimit = getCurrentRateLimit()
        return (
            isLimited: currentLimit.isLimited,
            remainingRequests: currentLimit.remainingRequests,
            timeUntilReset: currentLimit.timeUntilReset
        )
    }
    
    func resetRateLimit() {
        let newLimit = RateLimit(
            requestLimit: defaultLimit,
            timeWindowHours: defaultTimeWindow,
            requestCount: 0,
            windowStartTime: Date()
        )
        saveRateLimit(newLimit)
    }
}