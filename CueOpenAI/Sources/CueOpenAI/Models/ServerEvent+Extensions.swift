import Foundation

// MARK: - Server Events

extension ServerEvent {
    public struct ConversationCreatedEvent: Codable, Identifiable, Sendable {
        public let eventId: String
        public let type: String
        public let conversation: Conversation
        
        public var id: String { eventId }
        
        enum CodingKeys: String, CodingKey {
            case eventId = "event_id"
            case type, conversation
        }
    }
    
    public struct Conversation: Codable, Identifiable, Sendable {
        public let id: String
        public let object: String
    }
    
    public struct ConversationItemCreatedEvent: Decodable, Sendable {
        public let eventId: String
        public let type: String
        public let previousItemId: String?
        public let item: ConversationItem
    }
    
    public struct InputAudioBufferCommittedEvent: Decodable, Sendable {
        public let eventId: String
        public let type: String
        public let previousItemId: String?
        public let itemId: String
    }

    public struct InputAudioBufferClearedEvent: Codable, Sendable {
        public let eventId: String
        public let type: String
    }

    public struct InputAudioBufferSpeechStartedEvent: Decodable, Sendable {
        public let eventId: String
        public let type: String
        public let audioStartMs: Int
        public let itemId: String
    }

    public struct InputAudioBufferSpeechStoppedEvent: Decodable, Sendable {
        public let eventId: String
        public let type: String
        public let audioEndMs: Int
        public let itemId: String
    }
    
    public struct ConversationItemInputAudioTranscriptionCompletedEvent: Decodable, Sendable {
        public let eventId: String
        public let type: String
        public let itemId: String
        public let contentIndex: Int
        public let transcript: String
    }

    public struct ConversationItemInputAudioTranscriptionFailedEvent: Decodable, Sendable {
        public let eventId: String
        public let type: String
        public let itemId: String
        public let contentIndex: Int
        public let error: ErrorDetail
    }

    public struct ConversationItemTruncatedEvent: Decodable, Sendable {
        public let eventId: String
        public let type: String
        public let itemId: String
        public let contentIndex: Int
        public let audioEndMs: Int
    }

    public struct ConversationItemDeletedEvent: Decodable, Sendable {
        public let eventId: String
        public let type: String
        public let itemId: String
    }
    
    public struct RateLimitsUpdatedEvent: Decodable, Sendable {
        public struct RateLimit: Decodable, Sendable {
            public let name: String
            public let limit: Int
            public let remaining: Int
            public let resetSeconds: Double
        }
        
        public let eventId: String
        public let type: String
        public let rateLimits: [RateLimit]
    }
}
