import Foundation

// MARK: - Server Events

public enum ServerEvent: Decodable, Identifiable, Sendable {
    
    case error(ServerError)
    case sessionCreated(SessionCreatedEvent)
    case sessionUpdated(SessionUpdatedEvent)
    case conversationCreated(ConversationCreatedEvent)
    case conversationItemCreated(ConversationItemCreatedEvent)
    case conversationItemInputAudioTranscriptionCompleted(ConversationItemInputAudioTranscriptionCompletedEvent)
    case conversationItemInputAudioTranscriptionFailed(ConversationItemInputAudioTranscriptionFailedEvent)
    case conversationItemTruncated(ConversationItemTruncatedEvent)
    case conversationItemDeleted(ConversationItemDeletedEvent)
    case inputAudioBufferCommitted(InputAudioBufferCommittedEvent)
    case inputAudioBufferCleared(InputAudioBufferClearedEvent)
    case inputAudioBufferSpeechStarted(InputAudioBufferSpeechStartedEvent)
    case inputAudioBufferSpeechStopped(InputAudioBufferSpeechStoppedEvent)
    case responseCreated(ResponseCreatedEvent)
    case responseDone(ResponseDoneEvent)
    case responseOutputItemAdded(ResponseOutputItemAddedEvent)
    case responseOutputItemDone(ResponseOutputItemDoneEvent)
    case responseContentPartAdded(ResponseContentPartAddedEvent)
    case responseContentPartDone(ResponseContentPartDoneEvent)
    case responseTextDelta(ResponseTextDeltaEvent)
    case responseTextDone(ResponseTextDoneEvent)
    case responseAudioTranscriptDelta(ResponseAudioTranscriptDeltaEvent)
    case responseAudioTranscriptDone(ResponseAudioTranscriptDoneEvent)
    case responseAudioDelta(ResponseAudioDeltaEvent)
    case responseAudioDone(ResponseAudioDoneEvent)
    case responseFunctionCallArgumentsDelta(ResponseFunctionCallArgumentsDeltaEvent)
    case responseFunctionCallArgumentsDone(ResponseFunctionCallArgumentsDoneEvent)
    case rateLimitsUpdated(RateLimitsUpdatedEvent)
    
    // Delegate `id` to associated event's `id`
    public var id: String {
        switch self {
        case .error(let event):
            return event.eventId
        case .sessionCreated(let event):
            return event.eventId
        case .sessionUpdated(let event):
            return event.eventId
        case .conversationCreated(let event):
            return event.eventId
        case .conversationItemCreated(let event):
            return event.eventId
        case .conversationItemInputAudioTranscriptionCompleted(let event):
            return event.eventId
        case .conversationItemInputAudioTranscriptionFailed(let event):
            return event.eventId
        case .conversationItemTruncated(let event):
            return event.eventId
        case .conversationItemDeleted(let event):
            return event.eventId
        case .inputAudioBufferCommitted(let event):
            return event.eventId
        case .inputAudioBufferCleared(let event):
            return event.eventId
        case .inputAudioBufferSpeechStarted(let event):
            return event.eventId
        case .inputAudioBufferSpeechStopped(let event):
            return event.eventId
        case .responseCreated(let event):
            return event.eventId
        case .responseDone(let event):
            return event.eventId
        case .responseOutputItemAdded(let event):
            return event.eventId
        case .responseOutputItemDone(let event):
            return event.eventId
        case .responseContentPartAdded(let event):
            return event.eventId
        case .responseContentPartDone(let event):
            return event.eventId
        case .responseTextDelta(let event):
            return event.eventId
        case .responseTextDone(let event):
            return event.eventId
        case .responseAudioTranscriptDelta(let event):
            return event.eventId
        case .responseAudioTranscriptDone(let event):
            return event.eventId
        case .responseAudioDelta(let event):
            return event.eventId
        case .responseAudioDone(let event):
            return event.eventId
        case .responseFunctionCallArgumentsDelta(let event):
            return event.eventId
        case .responseFunctionCallArgumentsDone(let event):
            return event.eventId
        case .rateLimitsUpdated(let event):
            return event.eventId
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case type
    }
    
    enum EventType: String, Codable {
        case error
        case sessionCreated = "session.created"
        case sessionUpdated = "session.updated"
        case conversationCreated = "conversation.created"
        case conversationItemCreated = "conversation.item.created"
        case conversationItemInputAudioTranscriptionCompleted = "conversation.item.input_audio_transcription.completed"
        case conversationItemInputAudioTranscriptionFailed = "conversation.item.input_audio_transcription.failed"
        case conversationItemTruncated = "conversation.item.truncated"
        case conversationItemDeleted = "conversation.item.deleted"
        case inputAudioBufferCommitted = "input_audio_buffer.committed"
        case inputAudioBufferCleared = "input_audio_buffer.cleared"
        case inputAudioBufferSpeechStarted = "input_audio_buffer.speech_started"
        case inputAudioBufferSpeechStopped = "input_audio_buffer.speech_stopped"
        case responseCreated = "response.created"
        case responseDone = "response.done"
        case responseOutputItemAdded = "response.output_item.added"
        case responseOutputItemDone = "response.output_item.done"
        case responseContentPartAdded = "response.content_part.added"
        case responseContentPartDone = "response.content_part.done"
        case responseTextDelta = "response.text.delta"
        case responseTextDone = "response.text.done"
        case responseAudioTranscriptDelta = "response.audio_transcript.delta"
        case responseAudioTranscriptDone = "response.audio_transcript.done"
        case responseAudioDelta = "response.audio.delta"
        case responseAudioDone = "response.audio.done"
        case responseFunctionCallArgumentsDelta = "response.function_call_arguments.delta"
        case responseFunctionCallArgumentsDone = "response.function_call_arguments.done"
        case rateLimitsUpdated = "rate_limits.updated"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let eventType = try container.decode(String.self, forKey: .type)
        
        switch eventType {
        case "error":
            self = try .error(ServerError(from: decoder))
        case "session.created":
            self = try .sessionCreated(SessionCreatedEvent(from: decoder))
        case "session.updated":
            self = try .sessionUpdated(SessionUpdatedEvent(from: decoder))
        case "conversation.created":
            self = try .conversationCreated(ConversationCreatedEvent(from: decoder))
        case "input_audio_buffer.committed":
            self = try .inputAudioBufferCommitted(InputAudioBufferCommittedEvent(from: decoder))
        case "input_audio_buffer.cleared":
            self = try .inputAudioBufferCleared(InputAudioBufferClearedEvent(from: decoder))
        case "input_audio_buffer.speech_started":
            self = try .inputAudioBufferSpeechStarted(InputAudioBufferSpeechStartedEvent(from: decoder))
        case "input_audio_buffer.speech_stopped":
            self = try .inputAudioBufferSpeechStopped(InputAudioBufferSpeechStoppedEvent(from: decoder))
        case "conversation.item.created":
            self = try .conversationItemCreated(ConversationItemCreatedEvent(from: decoder))
        case "conversation.item.input_audio_transcription.completed":
            self = try .conversationItemInputAudioTranscriptionCompleted(ConversationItemInputAudioTranscriptionCompletedEvent(from: decoder))
        case "conversation.item.input_audio_transcription.failed":
            self = try .conversationItemInputAudioTranscriptionFailed(ConversationItemInputAudioTranscriptionFailedEvent(from: decoder))
        case "conversation.item.truncated":
            self = try .conversationItemTruncated(ConversationItemTruncatedEvent(from: decoder))
        case "conversation.item.deleted":
            self = try .conversationItemDeleted(ConversationItemDeletedEvent(from: decoder))
        case "response.created":
            self = try .responseCreated(ResponseCreatedEvent(from: decoder))
        case "response.done":
            self = try .responseDone(ResponseDoneEvent(from: decoder))
        case "response.output_item.added":
            self = try .responseOutputItemAdded(ResponseOutputItemAddedEvent(from: decoder))
        case "response.output_item.done":
            self = try .responseOutputItemDone(ResponseOutputItemDoneEvent(from: decoder))
        case "response.content_part.added":
            self = try .responseContentPartAdded(ResponseContentPartAddedEvent(from: decoder))
        case "response.content_part.done":
            self = try .responseContentPartDone(ResponseContentPartDoneEvent(from: decoder))
        case "response.text.delta":
            self = try .responseTextDelta(ResponseTextDeltaEvent(from: decoder))
        case "response.text.done":
            self = try .responseTextDone(ResponseTextDoneEvent(from: decoder))
        case "response.audio_transcript.delta":
            self = try .responseAudioTranscriptDelta(ResponseAudioTranscriptDeltaEvent(from: decoder))
        case "response.audio_transcript.done":
            self = try .responseAudioTranscriptDone(ResponseAudioTranscriptDoneEvent(from: decoder))
        case "response.audio.delta":
            self = try .responseAudioDelta(ResponseAudioDeltaEvent(from: decoder))
        case "response.audio.done":
            self = try .responseAudioDone(ResponseAudioDoneEvent(from: decoder))
        case "response.function_call_arguments.delta":
            self = try .responseFunctionCallArgumentsDelta(ResponseFunctionCallArgumentsDeltaEvent(from: decoder))
        case "response.function_call_arguments.done":
            self = try .responseFunctionCallArgumentsDone(ResponseFunctionCallArgumentsDoneEvent(from: decoder))
        case "rate_limits.updated":
            self = try .rateLimitsUpdated(RateLimitsUpdatedEvent(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown event type: \(eventType)")
        }
    }
        // Optionally, add a computed property to get the event type as a String
    public var type: String {
        switch self {
        case .error:
            return "error"
        case .sessionCreated:
            return "session.created"
        case .sessionUpdated:
            return "session.updated"
        case .conversationCreated:
            return "conversation.created"
        case .conversationItemCreated:
            return "conversation.item.created"
        case .conversationItemInputAudioTranscriptionCompleted:
            return "conversation.item.input_audio_transcription.completed"
        case .conversationItemInputAudioTranscriptionFailed:
            return "conversation.item.input_audio_transcription.failed"
        case .conversationItemTruncated:
            return "conversation.item.truncated"
        case .conversationItemDeleted:
            return "conversation.item.deleted"
        case .inputAudioBufferCommitted:
            return "input_audio_buffer.committed"
        case .inputAudioBufferCleared:
            return "input_audio_buffer.cleared"
        case .inputAudioBufferSpeechStarted:
            return "input_audio_buffer.speech_started"
        case .inputAudioBufferSpeechStopped:
            return "input_audio_buffer.speech_stopped"
        case .responseCreated:
            return "response.created"
        case .responseDone:
            return "response.done"
        case .responseOutputItemAdded:
            return "response.output_item.added"
        case .responseOutputItemDone:
            return "response.output_item.done"
        case .responseContentPartAdded:
            return "response.content_part.added"
        case .responseContentPartDone:
            return "response.content_part.done"
        case .responseTextDelta:
            return "response.text.delta"
        case .responseTextDone:
            return "response.text.done"
        case .responseAudioTranscriptDelta:
            return "response.audio_transcript.delta"
        case .responseAudioTranscriptDone:
            return "response.audio_transcript.done"
        case .responseAudioDelta:
            return "response.audio.delta"
        case .responseAudioDone:
            return "response.audio.done"
        case .responseFunctionCallArgumentsDelta:
            return "response.function_call_arguments.delta"
        case .responseFunctionCallArgumentsDone:
            return "response.function_call_arguments.done"
        case .rateLimitsUpdated:
            return "rate_limits.updated"
        }
    }
}
