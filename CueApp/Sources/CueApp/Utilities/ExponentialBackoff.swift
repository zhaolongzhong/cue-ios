import Foundation

struct ExponentialBackoff {
    struct Configuration {
        let initial: TimeInterval
        let maxDelay: TimeInterval
        let maxAttempts: Int
        let jitterFactor: Double

        static let defaultConfig = Configuration(
            initial: 1.0,    // 1 second
            maxDelay: 30.0,  // 30 seconds
            maxAttempts: 5,  // Maximum retry attempts
            jitterFactor: 0.2 // ±20% jitter
        )
    }

    static func calculateDelay(
        retryCount: Int,
        configuration: Configuration = .defaultConfig
    ) -> TimeInterval {
        guard retryCount < configuration.maxAttempts else {
            return configuration.maxDelay
        }

        // Calculate base delay: 2^retryCount seconds
        let baseDelay = TimeInterval(pow(2.0, Double(retryCount)))

        // Apply max delay cap
        let cappedDelay = min(baseDelay, configuration.maxDelay)

        // Apply jitter: delay ± 20%
        let jitterRange = cappedDelay * configuration.jitterFactor
        let jitter = TimeInterval.random(in: -jitterRange...jitterRange)

        return max(configuration.initial, cappedDelay + jitter)
    }
}
