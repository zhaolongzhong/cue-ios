import Foundation
import CueCommon

// MARK: - Streaming Types
extension Anthropic {
    // Streaming delegate to receive events
    public protocol StreamingDelegate: AnyObject {
        func didReceiveMessageStart(_ message: Message) async
        func didReceiveContentBlockStart(index: Int, contentBlock: ContentBlockStartEvent.ContentBlockStart) async
        func didReceiveContentBlockDelta(index: Int, delta: ContentBlockDeltaEvent.DeltaContent) async
        func didReceiveContentBlockStop(index: Int) async
        func didReceiveMessageDelta(stopReason: String?, stopSequence: String?, usage: Usage) async
        func didReceiveMessageStop() async
        func didReceivePing() async
        func didReceiveError(_ error: Error) async
        func didCompleteWithError(_ error: Error) async
    }

    // Event types for SSE streaming
    public enum StreamEventType: String, Codable {
        case messageStart = "message_start"
        case contentBlockStart = "content_block_start"
        case contentBlockDelta = "content_block_delta"
        case contentBlockStop = "content_block_stop"
        case messageDelta = "message_delta"
        case messageStop = "message_stop"
        case ping = "ping"
    }

    // Base type for all stream events
    public struct StreamEvent: Codable {
        public let type: StreamEventType

        private enum CodingKeys: String, CodingKey {
            case type
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeString = try container.decode(String.self, forKey: .type)
            guard let eventType = StreamEventType(rawValue: typeString) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .type,
                    in: container,
                    debugDescription: "Unknown event type: \(typeString)"
                )
            }
            self.type = eventType
        }
    }

    // Message start event
    public struct MessageStartEvent: Codable {
        public let type: String
        public let message: Message
    }

    // Content block delta event
    public struct ContentBlockDeltaEvent: Codable {
        public let type: String
        public let index: Int
        public let delta: DeltaContent

        public enum DeltaType: String, Codable {
            case textDelta = "text_delta"
            case inputJsonDelta = "input_json_delta"
            case thinkingDelta = "thinking_delta"
            case signatureDelta = "signature_delta"
        }

        public enum DeltaContent: Codable, Sendable {
            case textDelta(TextDelta)
            case inputJsonDelta(InputJsonDelta)
            case thinkingDelta(ThinkingDelta)
            case signatureDelta(SignatureDelta)

            public struct TextDelta: Codable, Sendable {
                public let type: String
                public let text: String
            }

            public struct InputJsonDelta: Codable, Sendable {
                public let type: String
                public let partialJson: String

                enum CodingKeys: String, CodingKey {
                    case type
                    case partialJson = "partial_json"
                }
            }

            public struct ThinkingDelta: Codable, Sendable {
                public let type: String
                public let thinking: String
            }

            public struct SignatureDelta: Codable, Sendable {
                public let type: String
                public let signature: String
            }

            private enum CodingKeys: String, CodingKey {
                case type
            }

            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let type = try container.decode(String.self, forKey: .type)

                switch type {
                case "text_delta":
                    self = .textDelta(try TextDelta(from: decoder))
                case "input_json_delta":
                    self = .inputJsonDelta(try InputJsonDelta(from: decoder))
                case "thinking_delta":
                    self = .thinkingDelta(try ThinkingDelta(from: decoder))
                case "signature_delta":
                    self = .signatureDelta(try SignatureDelta(from: decoder))
                default:
                    throw DecodingError.dataCorruptedError(
                        forKey: .type,
                        in: container,
                        debugDescription: "Unknown delta type: \(type)"
                    )
                }
            }

            public func encode(to encoder: Encoder) throws {
                switch self {
                case .textDelta(let delta):
                    try delta.encode(to: encoder)
                case .inputJsonDelta(let delta):
                    try delta.encode(to: encoder)
                case .thinkingDelta(let delta):
                    try delta.encode(to: encoder)
                case .signatureDelta(let delta):
                    try delta.encode(to: encoder)
                }
            }
        }

        enum CodingKeys: String, CodingKey {
            case type
            case index
            case delta
        }
    }

    // Content block stop event
    public struct ContentBlockStopEvent: Codable {
        public let type: String
        public let index: Int
    }

    // Message delta event
    public struct MessageDeltaEvent: Codable {
        public let type: String
        public let delta: Delta
        public let usage: Usage

        public struct Delta: Codable {
            public let stopReason: String?
            public let stopSequence: String?

            enum CodingKeys: String, CodingKey {
                case stopReason = "stop_reason"
                case stopSequence = "stop_sequence"
            }
        }

        enum CodingKeys: String, CodingKey {
            case type
            case delta
            case usage
        }
    }

    // Message stop event
    public struct MessageStopEvent: Codable {
        public let type: String
    }

    // Ping event
    public struct PingEvent: Codable {
        public let type: String
    }

    // Represents all possible event types
    public enum StreamResponse: Codable {
        case messageStart(MessageStartEvent)
        case contentBlockStart(ContentBlockStartEvent)
        case contentBlockDelta(ContentBlockDeltaEvent)
        case contentBlockStop(ContentBlockStopEvent)
        case messageDelta(MessageDeltaEvent)
        case messageStop(MessageStopEvent)
        case ping(PingEvent)

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()

            if let event = try? container.decode(StreamEvent.self) {
                switch event.type {
                case .messageStart:
                    self = .messageStart(try container.decode(MessageStartEvent.self))
                case .contentBlockStart:
                    self = .contentBlockStart(try container.decode(ContentBlockStartEvent.self))
                case .contentBlockDelta:
                    self = .contentBlockDelta(try container.decode(ContentBlockDeltaEvent.self))
                case .contentBlockStop:
                    self = .contentBlockStop(try container.decode(ContentBlockStopEvent.self))
                case .messageDelta:
                    self = .messageDelta(try container.decode(MessageDeltaEvent.self))
                case .messageStop:
                    self = .messageStop(try container.decode(MessageStopEvent.self))
                case .ping:
                    self = .ping(try container.decode(PingEvent.self))
                }
            } else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unknown event type"
                )
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()

            switch self {
            case .messageStart(let event):
                try container.encode(event)
            case .contentBlockStart(let event):
                try container.encode(event)
            case .contentBlockDelta(let event):
                try container.encode(event)
            case .contentBlockStop(let event):
                try container.encode(event)
            case .messageDelta(let event):
                try container.encode(event)
            case .messageStop(let event):
                try container.encode(event)
            case .ping(let event):
                try container.encode(event)
            }
        }
    }

    // Content block start event with tool use support
    public struct ContentBlockStartEvent: Codable, Sendable {
        public let type: String
        public let index: Int
        public let contentBlock: ContentBlockStart

        public enum ContentBlockStart: Codable, Sendable {
            case text(TextBlock)
            case toolUse(ToolUseBlock)
            case thinking(ThinkingBlock)

            public struct TextBlock: Codable, Sendable {
                public let type: String
                public let text: String
            }

            public struct ToolUseBlock: Codable, Sendable {
                public let type: String
                public let id: String
                public let name: String
                public let input: [String: JSONValue]

                enum CodingKeys: String, CodingKey {
                    case type
                    case id
                    case name
                    case input
                }
            }

            public struct ThinkingBlock: Codable, Sendable {
                public let type: String
                public let thinking: String
            }

            private enum CodingKeys: String, CodingKey {
                case type
            }

            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let type = try container.decode(String.self, forKey: .type)

                switch type {
                case "text":
                    self = .text(try TextBlock(from: decoder))
                case "tool_use":
                    self = .toolUse(try ToolUseBlock(from: decoder))
                case "thinking":
                    self = .thinking(try ThinkingBlock(from: decoder))
                default:
                    throw DecodingError.dataCorruptedError(
                        forKey: .type,
                        in: container,
                        debugDescription: "Unknown content block type: \(type)"
                    )
                }
            }

            public func encode(to encoder: Encoder) throws {
                switch self {
                case .text(let block):
                    try block.encode(to: encoder)
                case .toolUse(let block):
                    try block.encode(to: encoder)
                case .thinking(let block):
                    try block.encode(to: encoder)
                }
            }
        }

        enum CodingKeys: String, CodingKey {
            case type
            case index
            case contentBlock = "content_block"
        }
    }
}
