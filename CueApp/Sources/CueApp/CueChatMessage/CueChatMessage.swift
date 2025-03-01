import Foundation
import CueCommon
import CueOpenAI
import CueAnthropic
import CueGemini

public enum CueChatMessage: Encodable, Sendable, Identifiable, Equatable {
    case local(OpenAI.ChatMessageParam, stableId: String? = nil, streamingState: StreamingState? = nil, createdAt: Date? = nil)
    case openAI(OpenAI.ChatMessageParam, stableId: String? = nil, streamingState: StreamingState? = nil, createdAt: Date? = nil)
    case anthropic(Anthropic.ChatMessageParam, stableId: String? = nil, streamingState: StreamingState? = nil, createdAt: Date? = nil)
    case gemini(Gemini.ChatMessageParam, stableId: String? = nil, streamingState: StreamingState? = nil, createdAt: Date? = nil)
    case cue(MessageModel, stableId: String? = nil, streamingState: StreamingState? = nil, createdAt: Date? = nil)

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .local(let msg, _, _, _):
            try container.encode(msg)
        case .openAI(let msg, _, _, _):
            try container.encode(msg)
        case .anthropic(let msg, _, _, _):
            try container.encode(msg)
        case .gemini(let msg, _, _, _):
            try container.encode(msg)
        case .cue(let msg, _, _, _):
            try container.encode(msg)
        }
    }
}
