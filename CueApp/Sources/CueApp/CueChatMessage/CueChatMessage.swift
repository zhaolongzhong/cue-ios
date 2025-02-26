import Foundation
import CueCommon
import CueOpenAI
import CueAnthropic
import CueGemini

public enum CueChatMessage: Encodable, Sendable, Identifiable {
    case local(OpenAI.ChatMessageParam, stableId: String? = nil, streamingState: StreamingState? = nil)
    case openAI(OpenAI.ChatMessageParam, stableId: String? = nil, streamingState: StreamingState? = nil)
    case anthropic(Anthropic.ChatMessageParam, stableId: String? = nil, streamingState: StreamingState? = nil)
    case gemini(Gemini.ChatMessageParam, stableId: String? = nil, streamingState: StreamingState? = nil)
    case cue(MessageModel, stableId: String? = nil, streamingState: StreamingState? = nil)

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .local(let msg, _, _):
            try container.encode(msg)
        case .openAI(let msg, _, _):
            try container.encode(msg)
        case .anthropic(let msg, _, _):
            try container.encode(msg)
        case .gemini(let msg, _, _):
            try container.encode(msg)
        case .cue(let msg, _, _):
            try container.encode(msg)
        }
    }
}

extension CueChatMessage: Equatable {
    public static func == (lhs: CueChatMessage, rhs: CueChatMessage) -> Bool {
        // Basic identity check
        guard lhs.id == rhs.id, lhs.content == rhs.content else {
            return false
        }

        // If both are .local, compare the streamingState in detail
        if case .local(_, _, let lhsStreaming) = lhs,
           case .local(_, _, let rhsStreaming) = rhs {
            if let lhsStreamingState = lhsStreaming,
               let rhsStreamingState = rhsStreaming {
                return lhsStreamingState.isComplete == rhsStreamingState.isComplete
            }
        }
        if case .anthropic(_, _, let lhsStreaming) = lhs,
           case .anthropic(_, _, let rhsStreaming) = rhs {
            if let lhsStreamingState = lhsStreaming,
               let rhsStreamingState = rhsStreaming {
                let res = lhsStreamingState.isComplete == rhsStreamingState.isComplete &&
                       lhsStreamingState.contentBlocks == rhsStreamingState.contentBlocks

                return res
            }
        }
        return true
    }
}
