import Foundation

// MARK: - Client Events

public enum ClientEvent: Encodable, Sendable {
    case sessionUpdate(SessionUpdateEvent)
    case inputAudioBufferAppend(InputAudioBufferAppendEvent)
    case inputAudioBufferCommit(InputAudioBufferCommitEvent)
    case inputAudioBufferClear(InputAudioBufferClearEvent)
    case conversationItemCreate(ConversationItemCreateEvent)
    case conversationItemTruncate(ConversationItemTruncateEvent)
    case conversationItemDelete(ConversationItemDeleteEvent)
    case responseCreate(ResponseCreateEvent)
    case responseCancel(ResponseCancelEvent)
    
    enum CodingKeys: String, CodingKey {
        case type
    }
    
    enum EventType: String, Encodable {
        case sessionUpdate = "session.update"
        case inputAudioBufferAppend = "input_audio_buffer.append"
        case inputAudioBufferCommit = "input_audio_buffer.commit"
        case inputAudioBufferClear = "input_audio_buffer.clear"
        case conversationItemCreate = "conversation.item.create"
        case conversationItemTruncate = "conversation.item.truncate"
        case conversationItemDelete = "conversation.item.delete"
        case responseCreate = "response.create"
        case responseCancel = "response.cancel"
    }
    
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .sessionUpdate(let event):
            try event.encode(to: encoder)
        case .inputAudioBufferAppend(let event):
            try event.encode(to: encoder)
        case .inputAudioBufferCommit(let event):
            try event.encode(to: encoder)
        case .inputAudioBufferClear(let event):
            try event.encode(to: encoder)
        case .conversationItemCreate(let event):
            try event.encode(to: encoder)
        case .conversationItemTruncate(let event):
            try event.encode(to: encoder)
        case .conversationItemDelete(let event):
            try event.encode(to: encoder)
        case .responseCreate(let event):
            try event.encode(to: encoder)
        case .responseCancel(let event):
            try event.encode(to: encoder)
        }
    }
    
    public struct SessionUpdateEvent: Encodable, Sendable {
        let type: String
        let session: SessionUpdate
        
        public init(type: String, session: SessionUpdate) {
            self.type = type
            self.session = session
        }
    }
    
    public struct SessionUpdate: Encodable, Sendable {        
        let modalities: [Modality]
        let instructions: String
        let voice: Voice
        let inputAudioFormat: AudioFormat
        let outputAudioFormat: AudioFormat
        let inputAudioTranscription: InputAudioTranscription?
        let turnDetection: TurnDetection?
        let tools: [FunctionDefinition]
        let toolChoice: ToolChoice
        let temperature: Double
        let maxResponseOutputTokens: MaxTokens
    }
    
    public struct InputAudioBufferAppendEvent: Encodable, Sendable {
        public let eventId: String?
        public let audio: String
        private let type: String = "input_audio_buffer.append"
    }
    
    public struct InputAudioBufferCommitEvent: Encodable, Sendable {
        public let eventId: String?
        private let type = "input_audio_buffer.commit"
    }

    public struct InputAudioBufferClearEvent: Encodable, Sendable {
        public let eventId: String?
        private let type = "input_audio_buffer.clear"
    }
    
    public struct ConversationItemCreateEvent: Encodable, Sendable {
        public let previousItemId: String?
        public let item: ConversationItem
        private let type = "conversation.item.create"
        
        public init(previousItemId: String?, item: ConversationItem) {
            self.previousItemId = previousItemId
            self.item = item
        }
    }
    
    public struct ConversationItemTruncateEvent: Encodable, Sendable {
        public let eventId: String?
        public let itemId: String?
        public let contentIndex: Int
        public let audioEndMs: Int
        
        private let type = "conversation.item.truncate"
    }
    
    public struct ConversationItemDeleteEvent: Encodable, Sendable {
        public let eventId: String
        public let itemId: String
        
        private let type = "conversation.item.delete"
    }
    
    public struct ResponseCreateEvent: Encodable, Sendable {
        public let response: ResponseCreate?
        private let type = "response.create"
    }

    public struct ResponseCreate: Encodable, Sendable {
        let modalities: [Modality]
        let instructions: String
        let voice: Voice
        let outputAudioFormat: AudioFormat
        let tools: [Tool]
        let toolChoice: ToolChoice
        let temperature: Double
        let maxOutputTokens: MaxTokens
    }

    public struct ResponseCancelEvent: Encodable, Sendable {
        let eventId: String?
        let type: String
        let responseId: String?
    }
}

public struct SessionUpdateBuilder {
    public var modalities: Set<Modality>? = nil
    public var instructions: String? = nil
    public var voice: Voice? = nil
    public var inputAudioFormat: AudioFormat? = nil
    public var outputAudioFormat: AudioFormat? = nil
    public var inputAudioTranscription: InputAudioTranscription? = nil
    public var turnDetection: TurnDetection? = nil
    public var tools: [FunctionDefinition]? = nil
    public var toolChoice: ToolChoice? = nil
    public var temperature: Double? = nil
    public var maxOutputTokens: Int? = nil
    
    public init() {}
    
    public func build() -> ClientEvent.SessionUpdate {
        ClientEvent.SessionUpdate(
            modalities: Array(modalities ?? [.text, .audio]),
            instructions: instructions ?? "",
            voice: voice ?? .alloy,
            inputAudioFormat: inputAudioFormat ?? .pcm16,
            outputAudioFormat: outputAudioFormat ?? .pcm16,
            inputAudioTranscription: inputAudioTranscription ?? InputAudioTranscription(model: "whisper-1"),
            turnDetection: turnDetection,
            tools: tools ?? [],
            toolChoice: toolChoice ?? .auto,
            temperature: temperature ?? 0.8,
            maxResponseOutputTokens: maxOutputTokens != nil ? .integer(maxOutputTokens!) : .infinity
        )
    }
}
