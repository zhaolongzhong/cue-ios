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
        case .anthropic(_, _, let streamingState):
            return streamingState
        default:
            return nil
        }
    }

    var isStreaming: Bool {
        guard let streamingState = streamingState else {
            return false
        }
        return streamingState.isComplete == false
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

    /// Updates the streaming state of a message
    func updateStreamingState(_ newState: StreamingState) -> CueChatMessage {
        switch self {
        case .local(let msg, let stableId, _):
            return .local(msg, stableId: stableId, streamingState: newState)
        case .openAI(let msg, let stableId, _):
            return .local(msg, stableId: stableId, streamingState: newState)
        default:
            return self
        }
    }
}
