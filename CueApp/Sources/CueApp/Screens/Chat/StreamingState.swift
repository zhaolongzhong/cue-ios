import Foundation
import CueAnthropic
import CueOpenAI

public struct StreamingState: Codable, Equatable, Sendable {
    var id: String?
    var currentIndex: Int?
    var content: String = ""
    var contentBlocks: [Anthropic.ContentBlock] = []
    var chunks: [LocalStreamChunk] = []
    var toolCalls: [ToolCall] = []
    var isComplete: Bool = false
    var startTime: Date?
    var thinkingEndTime: Date?
    var endTime: Date?
    var isStreamingMode: Bool = false

    var isThinkingComplete: Bool {
        return thinkingEndTime != nil
    }

    var thinkingDuration: TimeInterval? {
        guard let start = self.startTime else { return nil }
        let effectiveEnd = self.thinkingEndTime ?? Date()
        return effectiveEnd.timeIntervalSince(start)
    }
}
