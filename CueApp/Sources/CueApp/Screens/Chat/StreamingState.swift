import Foundation
import CueAnthropic
import CueOpenAI

public struct StreamingState: Equatable, Sendable {
    var id: String?
    var currentIndex: Int?
    var accumulatedText = ""
    var content: String = ""
    var contentBlocks: [Anthropic.ContentBlock] = []
    var chunks: [LocalStreamChunk] = []
    var toolCalls: [ToolCall] = []
    var isComplete: Bool = false
    var startTime: Date?
    var thinkingEndTime: Date?
    var endTime: Date?
    var isStreamingMode: Bool = false

    // Track expanded/collapsed state for thinking blocks
    // Maps blockId -> isExpanded
    var expandedThinkingBlocks: [String: Bool] = [:]

    // Helper method to check if a thinking block is expanded
    func isThinkingBlockExpanded(id: String) -> Bool {
        // Default to expanded (true) if not specifically set to collapsed
        return expandedThinkingBlocks[id] ?? true
    }

    // Helper method to toggle a thinking block's expanded state
    func toggledThinkingBlock(id: String) -> StreamingState {
        var newState = self
        let currentValue = newState.isThinkingBlockExpanded(id: id)
        newState.expandedThinkingBlocks[id] = !currentValue
        return newState
    }

    var isThinkingComplete: Bool {
        return thinkingEndTime != nil
    }

    var thinkingDuration: TimeInterval? {
        guard let start = self.startTime else { return nil }
        let effectiveEnd = self.thinkingEndTime ?? Date()
        return effectiveEnd.timeIntervalSince(start)
    }
}
