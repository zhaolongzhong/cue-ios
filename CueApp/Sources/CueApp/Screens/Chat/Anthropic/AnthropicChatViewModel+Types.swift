import os
import Foundation
import CueAnthropic
import CueCommon

public enum StreamEvent {
    case text(String, String)
    case thinking(String, String)
    case thinkingSignature(String, Bool)
    case toolCall(String, [Anthropic.ToolUseBlock])
    case toolResult(String, CueChatMessage)

    // Streaming task lifecycle events
    case streamTaskStarted(String)  // messageId
    case streamTaskCompleted(String)  // messageId

    // Overall completion event
    case completed

    // Helper to extract the streaming ID if present
    var streamingId: String? {
        switch self {
        case .text(let id, _),
             .thinking(let id, _),
             .thinkingSignature(let id, _),
             .toolCall(let id, _),
             .toolResult(let id, _):
            return id
        case .streamTaskStarted(let id),
             .streamTaskCompleted(let id):
            return id
        case .completed:
            return nil
        }
    }
}

/// Result of processing a stream of events
struct StreamResult {
    var messageId: String = ""
    var finalMessage: Anthropic.ChatMessageParam?
    var toolResults: [Anthropic.ToolResultContent] = []
    var hasAllToolResults: Bool = true
}

/// Structure to track a pending tool call
struct PendingToolCall {
    let index: Int
    var jsonInput: String
    var name: String
    var id: String
}

/// Structure to track a thinking block
struct ThinkingBlock {
    let index: Int
    var content: String
    var signature: String
}
