//
//  ContentBlockDelta.swift
//  CueAnthropic
//

import Foundation

extension ServerStreamingEvent {
    /// Base protocol for all content block delta types
    public protocol ContentBlockDeltaType: Codable, Sendable {
        /// The type identifier for this delta type
        var type: String { get }
    }

    /// Text delta containing updated text content
    public struct TextDelta: ContentBlockDeltaType {
        public let type: String
        public let text: String

        public init(type: String = "text_delta", text: String) {
            self.type = type
            self.text = text
        }
    }

    /// Thinking delta containing thinking content
    public struct ThinkingDelta: ContentBlockDeltaType {
        public let type: String
        public let thinking: String

        public init(type: String = "thinking_delta", thinking: String) {
            self.type = type
            self.thinking = thinking
        }
    }

    /// Signature delta containing signature data
    public struct SignatureDelta: ContentBlockDeltaType {
        public let type: String
        public let signature: String

        public init(type: String = "signature_delta", signature: String) {
            self.type = type
            self.signature = signature
        }
    }


    /// Input JSON delta containing partial JSON for tool usage
    public struct InputJsonDelta: ContentBlockDeltaType {
        public let type: String
        public let partialJson: String

        public init(type: String = "input_json_delta", partialJson: String) {
            self.type = type
            self.partialJson = partialJson
        }

        // Custom coding keys to match API field names
        private enum CodingKeys: String, CodingKey {
            case type
            case partialJson = "partial_json"
        }
    }

    /// Tool use delta containing JSON input
    public struct ToolUseDelta: ContentBlockDeltaType {
        public let type: String
        public let id: String
        public let name: String

        public init(type: String = "tool_use", id: String, name: String) {
            self.type = type
            self.id = id
            self.name = name
        }
    }

    /// Unknown delta type for future compatibility
    public struct UnknownDelta: ContentBlockDeltaType {
        public let type: String
        public let data: [String: String]

        public init(type: String, data: [String: String] = [:]) {
            self.type = type
            self.data = data
        }
    }

    // MARK: - Enhanced ContentBlockDelta

    /// Enhanced representation of a delta update to a content block
    public enum ContentBlockDelta: Codable, Sendable {
        case text(TextDelta)
        case thinking(ThinkingDelta)
        case signature(SignatureDelta)
        case inputJson(InputJsonDelta)
        case toolUse(ToolUseDelta)

        case unknown(UnknownDelta)

        // MARK: - Convenience Properties

        /// Get the raw type string
        public var typeString: String {
            switch self {
            case .text(let delta):
                return delta.type
            case .thinking(let delta):
                return delta.type
            case .signature(let delta):
                return delta.type
            case .inputJson(let delta):
                return delta.type
            case .toolUse(let delta):
                return delta.type
            case .unknown(let delta):
                return delta.type
            }
        }
    }
}
