import Foundation
import CueCommon
import CueOpenAI
import CueAnthropic
import CueGemini

extension CueChatMessage {

    /// Returns the streaming state if this message is a streaming message
    var streamingState: StreamingState? {
        switch self {
        case .local(_, _, let streamingState):
            return streamingState
        default:
            return nil
        }
    }

    var isStreaming: Bool {
        return streamingState?.isComplete == false
    }

    /// Returns true if message contains thinking block tags
    var hasThinkingBlocks: Bool {
        return content.contentAsString.contains("<think>") && content.contentAsString.contains("</think>")
    }

    /// Generates a consistent block ID format
    func generateConsistentBlockId(index: Int) -> String {
        return "thinking_block_\(index)"
    }

    /// Extracts all thinking block IDs from content
    func extractThinkingBlockIds(from content: String) -> [String] {
        var blockIds = [String]()

        // Check if there are any thinking blocks in the content
        guard content.contains("<think") && content.contains("</think>") else {
            return blockIds
        }

        // Pattern to find all thinking blocks
        let pattern = #"<think[^>]*>.*?</think>"#
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
            let nsString = content as NSString
            let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: nsString.length))

            for index in matches.indices {
                blockIds.append(generateConsistentBlockId(index: index))
            }
        } catch {
            debugPrint("Error parsing thinking blocks: \(error)")
        }

        return blockIds
    }

    /// Toggles the expanded state of a thinking block
    func toggleThinkingBlock(id: String) -> CueChatMessage {
        // If we have a streamingState, use it
        if let state = streamingState {
            let updatedState = state.toggledThinkingBlock(id: id)
            return updateStreamingState(updatedState)
        }
        // For non-streaming messages with thinking blocks, create a new StreamingState
        else if hasThinkingBlocks {
            // Extract thinking block IDs from content
            let thinkingBlockIds = extractThinkingBlockIds(from: content.contentAsString)

            // Create initial StreamingState
            var newState = StreamingState(
                content: content.contentAsString,
                isComplete: true, // It's not streaming
                startTime: nil,   // No streaming timestamps
                thinkingEndTime: nil,
                endTime: nil
            )

            // Initialize expandedThinkingBlocks with default values (expanded)
            for blockId in thinkingBlockIds {
                newState.expandedThinkingBlocks[blockId] = true
            }

            // Toggle the specific block
            newState = newState.toggledThinkingBlock(id: id)
            return updateStreamingState(newState)
        }

        // If no thinking blocks, return unchanged
        return self
    }

    /// Checks if a thinking block is expanded
    func isThinkingBlockExpanded(id: String) -> Bool {
        return streamingState?.isThinkingBlockExpanded(id: id) ?? true
    }

    /// Updates the streaming state of a message
    func updateStreamingState(_ newState: StreamingState) -> CueChatMessage {
        switch self {
        case .local(let msg, let stableId, _):
            return .local(msg, stableId: stableId, streamingState: newState)
        case .openAI(let msg):
            // Convert openAI messages to local messages with the streaming state
            return .local(msg, stableId: id, streamingState: newState)
        default:
            return self
        }
    }
}
