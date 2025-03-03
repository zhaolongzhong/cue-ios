import Foundation
import CueCommon
import CueOpenAI
import CueAnthropic
import CueGemini

extension CueChatMessage {

    /// Returns the streaming state if this message is a streaming message
    var streamingState: StreamingState? {
        switch self {
        case .local(_, _, let streamingState, _),
                .openAI(_, _, let streamingState, _):
            return streamingState
        case .anthropic(_, _, let streamingState, _):
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

    /// Updates the streaming state of a message
    func updateStreamingState(_ newState: StreamingState) -> CueChatMessage {
        switch self {
        case .local(let msg, let stableId, _, _):
            return .local(msg, stableId: stableId, streamingState: newState)
        case .openAI(let msg, let stableId, _, _):
            return .local(msg, stableId: stableId, streamingState: newState)
        default:
            return self
        }
    }
}
