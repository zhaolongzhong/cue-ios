import Foundation

/// Metadata for usage tracking
public struct UsageMetadata: Codable, Sendable {
    /// Total count of tokens consumed
    public let totalTokenCount: Int

    public init(totalTokenCount: Int) {
        self.totalTokenCount = totalTokenCount
    }
}
