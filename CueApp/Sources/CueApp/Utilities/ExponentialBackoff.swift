import Foundation

public struct ExponentialBackoff: Sendable {
    public struct Configuration: Sendable {
        let initial: TimeInterval
        let maxDelay: TimeInterval
        let maxAttempts: Int
        let jitterFactor: Double

        public static let defaultConfig = Configuration(
            initial: 1.0,    // 1 second
            maxDelay: 60.0,  // 60 seconds
            maxAttempts: 5,  // Maximum retry attempts
            jitterFactor: 0.2 // ±20% jitter
        )
    }

    public static func calculateDelay(
        retryCount: Int,
        configuration: Configuration = .defaultConfig
    ) -> TimeInterval {
        // If we've reached max attempts, return the max delay
        guard retryCount <= configuration.maxAttempts else {
            return configuration.maxDelay
        }

        // For first attempt, use initial delay
        guard retryCount > 0 else {
            return configuration.initial
        }

        // Calculate base delay with exponential backoff: initial * 2^(retryCount-1)
        let baseDelay = configuration.initial * pow(2.0, Double(retryCount - 1))

        // Apply max delay cap
        let cappedDelay = min(baseDelay, configuration.maxDelay)

        // Apply jitter: delay ± jitterFactor%
        let jitterRange = cappedDelay * configuration.jitterFactor
        let jitter = TimeInterval.random(in: -jitterRange...jitterRange)

        return max(configuration.initial, cappedDelay + jitter)
    }
}
