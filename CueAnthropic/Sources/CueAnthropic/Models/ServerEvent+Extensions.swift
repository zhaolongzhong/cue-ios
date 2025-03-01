
//
//  AnthropicStreamingEvent.swift
//  CueAnthropic
//

import Foundation
import Combine
import os.log

// MARK: - Anthropic Core Types

extension ServerStreamingEvent {
    // MARK: - Event Types

    /// Event received when a message starts
    public struct MessageStartEvent: EventProtocol, Decodable, Sendable {
        public let id: String
        public let message: Anthropic.Message

        enum CodingKeys: String, CodingKey {
            case type
            case message
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.id = UUID().uuidString
            self.message = try container.decode(Anthropic.Message.self, forKey: .message)
        }

        public init(id: String, message: Anthropic.Message) {
            self.id = id
            self.message = message
        }
    }

    /// Event received when a content block starts
    public struct ContentBlockStartEvent: EventProtocol, Decodable, Sendable {
        public let id: String
        public let index: Int
        public let contentBlock: Anthropic.ContentBlock

        enum CodingKeys: String, CodingKey {
            case type
            case index
            case contentBlock = "content_block"
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.id = UUID().uuidString
            self.index = try container.decode(Int.self, forKey: .index)
            self.contentBlock = try container.decode(Anthropic.ContentBlock.self, forKey: .contentBlock)
        }

        public init(id: String, index: Int, contentBlock: Anthropic.ContentBlock) {
            self.id = id
            self.index = index
            self.contentBlock = contentBlock
        }
    }

    /// Event received when a content block receives delta content
    public struct ContentBlockDeltaEvent: Decodable, Identifiable, Sendable {
        public let id: String
        public let index: Int
        public let delta: ContentBlockDelta

        private enum CodingKeys: String, CodingKey {
            case type
            case index
            case delta
        }

        private enum DeltaKeys: String, CodingKey {
            case type
            case text
            case thinking
            case signature
            case json
            case partialJson = "partial_json"
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            self.id = UUID().uuidString
            self.index = try container.decode(Int.self, forKey: .index)

            // Decode the delta container
            let deltaContainer = try container.nestedContainer(keyedBy: DeltaKeys.self, forKey: .delta)

            // Get the delta type
            let deltaType = try deltaContainer.decode(String.self, forKey: .type)

            // Decode based on the type, with simpler direct access
            switch deltaType {
            case "text_delta":
                let text = try deltaContainer.decode(String.self, forKey: .text)
                self.delta = .text(TextDelta(type: deltaType, text: text))

            case "thinking_delta":
                let thinking = try deltaContainer.decode(String.self, forKey: .thinking)
                self.delta = .thinking(ThinkingDelta(type: deltaType, thinking: thinking))

            case "signature_delta":
                let signature = try deltaContainer.decode(String.self, forKey: .signature)
                self.delta = .signature(SignatureDelta(type: deltaType, signature: signature))

            case "input_json_delta":
                let partialJson = try deltaContainer.decode(String.self, forKey: .partialJson)
                self.delta = .inputJson(InputJsonDelta(type: deltaType, partialJson: partialJson))

            case "tool_use":
                let toolUseDetail = try deltaContainer.decode(ToolUseDelta.self, forKey: .json)
                self.delta = .toolUse(toolUseDetail)

            default:
                self.delta = .unknown(.init(type: deltaType))
            }
        }

        public init(id: String, index: Int, delta: ContentBlockDelta) {
            self.id = id
            self.index = index
            self.delta = delta
        }
    }

    /// Event received when a content block is complete
    public struct ContentBlockStopEvent: EventProtocol, Decodable, Sendable {
        public let id: String
        public let index: Int

        enum CodingKeys: String, CodingKey {
            case type
            case index
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.id = UUID().uuidString
            self.index = try container.decode(Int.self, forKey: .index)
        }

        public init(id: String, index: Int) {
            self.id = id
            self.index = index
        }
    }

    /// Event received for message delta updates
    public struct MessageDeltaEvent: EventProtocol, Decodable, Sendable {
        public let id: String
        public let delta: MessageDelta
        public let usage: Anthropic.Usage?

        enum CodingKeys: String, CodingKey {
            case type
            case delta
            case usage
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.id = UUID().uuidString
            self.delta = try container.decode(MessageDelta.self, forKey: .delta)
            self.usage = try container.decodeIfPresent(Anthropic.Usage.self, forKey: .usage)
        }

        public init(id: String, delta: MessageDelta, usage: Anthropic.Usage?) {
            self.id = id
            self.delta = delta
            self.usage = usage
        }
    }

    /// Event received when a message is complete
    public struct MessageStopEvent: EventProtocol, Decodable, Sendable {
        public let id: String

        enum CodingKeys: String, CodingKey {
            case type
        }

        public init(from decoder: Decoder) throws {
            self.id = UUID().uuidString
            // No additional properties to decode
        }

        public init(id: String) {
            self.id = id
        }
    }

    /// Event sent periodically to keep the connection alive
    public struct PingEvent: EventProtocol, Decodable, Sendable {
        public let id: String

        enum CodingKeys: String, CodingKey {
            case type
        }

        public init(from decoder: Decoder) throws {
            self.id = UUID().uuidString
            // No additional properties to decode
        }

        public init(id: String) {
            self.id = id
        }
    }

    /// Event received when an error occurs
    public struct ErrorEvent: EventProtocol, Decodable, Sendable {
        public let id: String
        public let error: Anthropic.APIError.ErrorDetails

        enum CodingKeys: String, CodingKey {
            case type
            case error
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.id = UUID().uuidString
            self.error = try container.decode(Anthropic.APIError.ErrorDetails.self, forKey: .error)
        }

        public init(id: String, error: Anthropic.APIError.ErrorDetails) {
            self.id = id
            self.error = error
        }
    }

    /// Represents a delta update to a message
    public struct MessageDelta: Codable, Sendable {
        public let stopReason: String?
        public let stopSequence: String?

        enum CodingKeys: String, CodingKey {
            case stopReason = "stop_reason"
            case stopSequence = "stop_sequence"
        }

        public init(stopReason: String?, stopSequence: String?) {
            self.stopReason = stopReason
            self.stopSequence = stopSequence
        }
    }
}
