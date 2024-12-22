import Foundation

// MARK: - Server Events

public enum ResponseStatus: String, Decodable, Sendable {
    case inProgress = "in_progress"
    case completed
    case interrupted
    case incomplete
    case cancelled
}

public struct StatusError: Decodable, Sendable {
    public let type: String?
    public let code: String?
    public let message: String?
}

public struct ResponseEvent: Decodable, Sendable {
    public let id: String
    public let object: String
    public let status: String
    public let statusDetails: StatusError?
    public let output: [ConversationItem]
    public let usage: RealtimeUsage?
    public let metadata: String?
}

public struct ResponseCreatedEvent: Decodable, Sendable {
    public let eventId: String
    public let type: String
    public let response: ResponseEvent
}

public struct ResponseDoneEvent: Decodable, Sendable {
    public let eventId: String
    public let type: String
    public let response: ResponseEvent
}

public struct ResponseCreateDoneEvent: Decodable, Sendable {
    public let event_id: String
    public let type: String
    public let response: ResponseEvent
}

public struct ResponseGeneratedEvent: Decodable, Sendable {
    public let event_id: String
    public let type: String
    public let response: ModelResponse
    
    public struct ModelResponse: Decodable, Sendable {
        public let content: [ContentPart]
    }
}

public struct ResponseOutputItemAddedEvent: Decodable, Sendable {
    public let eventId: String
    public let type: String
    public let responseId: String
    public let outputIndex: Int
    public let item: ConversationItem
}

public struct ResponseOutputItemDoneEvent: Decodable, Sendable {
    public let eventId: String
    public let type: String
    public let responseId: String
    public let outputIndex: Int
    public let item: ConversationItem
}

public struct ResponseContentPartAddedEvent: Decodable, Sendable {
    public let eventId: String
    public let type: String
    public let responseId: String
    public let itemId: String
    public let outputIndex: Int
    public let contentIndex: Int
    public let part: ContentPart
}

public struct ResponseContentPartDoneEvent: Decodable, Sendable {
    public let eventId: String
    public let type: String
    public let responseId: String
    public let itemId: String
    public let outputIndex: Int
    public let contentIndex: Int
    public let part: ContentPart
}

public struct ResponseTextDeltaEvent: Decodable, Sendable {
    public let eventId: String
    public let type: String
    public let responseId: String
    public let itemId: String
    public let outputIndex: Int
    public let contentIndex: Int
    public let delta: String
}

public struct ResponseTextDoneEvent: Decodable, Sendable {
    public let eventId: String
    public let type: String
    public let responseId: String
    public let itemId: String
    public let outputIndex: Int
    public let contentIndex: Int
    public let text: String
}

public struct ResponseAudioTranscriptDeltaEvent: Decodable, Sendable {
    public let eventId: String
    public let type: String
    public let responseId: String
    public let itemId: String
    public let outputIndex: Int
    public let contentIndex: Int
    public let delta: String
}

public struct ResponseAudioTranscriptDoneEvent: Decodable, Sendable {
    public let eventId: String
    public let type: String
    public let responseId: String
    public let itemId: String
    public let outputIndex: Int
    public let contentIndex: Int
    public let transcript: String
}

public struct ResponseAudioDeltaEvent: Decodable, Sendable {
    public let eventId: String
    public let type: String
    public let responseId: String
    public let itemId: String
    public let outputIndex: Int
    public let contentIndex: Int
    public let delta: String
}

public struct ResponseAudioDoneEvent: Decodable, Sendable {
    public let eventId: String
    public let type: String
    public let responseId: String
    public let itemId: String
    public let outputIndex: Int
    public let contentIndex: Int
}

public struct ResponseFunctionCallArgumentsDeltaEvent: Decodable, Sendable {
    public let eventId: String
    public let type: String
    public let responseId: String
    public let itemId: String
    public let outputIndex: Int
    public let callId: String
    public let delta: String
}

public struct ResponseFunctionCallArgumentsDoneEvent: Decodable, Sendable {
    public let eventId: String
    public let type: String
    public let responseId: String
    public let itemId: String
    public let outputIndex: Int
    public let callId: String
    public let arguments: String
}

public struct RealtimeUsage: Decodable, Sendable {
    public let totalTokens: Int
    public let inputTokens: Int
    public let outputTokens: Int
    public let inputTokenDetails: RealtimeTokenDetails
    public let outputTokenDetails: RealtimeTokenDetails
}

public struct RealtimeTokenDetails: Decodable, Sendable {
    public let textTokens: Int
    public let audioTokens: Int
    public let cachedTokens: Int?
    public let cachedTokensDetails: CachedTokensDetails?
}

public struct CachedTokensDetails: Decodable, Sendable {
    public let textTokens: Int
    public let audioTokens: Int
}
