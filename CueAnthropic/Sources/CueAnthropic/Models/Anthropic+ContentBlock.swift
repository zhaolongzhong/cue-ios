//
//  Anthropic+ContentBlock.swift
//  CueAnthropic
//

import CueCommon

extension Anthropic {
    public enum ContentType: String, Codable {
        case text
        case toolUse = "tool_use"
        case toolResult = "tool_result"
        case image
    }

    public struct Source: Codable, Equatable, Sendable {
        public let type: String  // Will always be "base64"
        public let data: String  // Base64 encoded image data
        public let mediaType: String  // MIME type e.g., "image/jpeg", "image/png"

        public enum CodingKeys: String, CodingKey {
            case type
            case data
            case mediaType = "media_type"
        }

        public init(type: String, data: String, mediaType: String) {
            self.type = type
            self.data = data
            self.mediaType = mediaType
        }
    }

    public struct CacheControlEphemeral: Codable, Equatable, Sendable {
        public let type: String  // Will always be "ephemeral"

        public init(type: String = "ephemeral") {
            self.type = type
        }
    }

    public struct ImageBlock: Codable, Equatable, Sendable {
        public let type: String  // Will always be "image"
        public let source: Source
        public let cacheControl: CacheControlEphemeral?

        public enum CodingKeys: String, CodingKey {
            case type
            case source
            case cacheControl = "cache_control"
        }

        public init(type: String, source: Source, cacheControl: CacheControlEphemeral? = nil) {
            self.type = type
            self.source = source
            self.cacheControl = cacheControl
        }
    }

    public struct TextBlock: Codable, Equatable, Sendable {
        public let text: String
        public let type: String  // Will always be "text"

        public init(text: String, type: String) {
            self.text = text
            self.type = type
        }
    }

    public struct ToolUseBlock: Codable, Equatable, Sendable {
        public let type: String  // Will always be "tool_use"
        public let id: String
        public let input: [String: JSONValue]
        public let name: String

        public enum CodingKeys: String, CodingKey {
            case type
            case id
            case input
            case name
        }

        public init(type: String, id: String, input: [String: JSONValue], name: String) {
            self.type = type
            self.id = id
            self.input = input
            self.name = name
        }
    }

    public enum ContentBlock: Codable, Equatable, Sendable {
        case text(TextBlock)
        case image(ImageBlock)
        case toolUse(ToolUseBlock)
        case thinking(ThinkingBlock)

        private enum CodingKeys: String, CodingKey {
            case type
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)

            switch type {
            case "text":
                let textBlock = try TextBlock(from: decoder)
                self = .text(textBlock)
            case "image":
                let imageBlock = try ImageBlock(from: decoder)
                self = .image(imageBlock)
            case "tool_use":
                let toolUseBlock = try ToolUseBlock(from: decoder)
                self = .toolUse(toolUseBlock)
            case "thinking":
                let thinkingBlock = try ThinkingBlock(from: decoder)
                self = .thinking(thinkingBlock)
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .type,
                    in: container,
                    debugDescription: "Unknown content block type: \(type)"
                )
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()

            switch self {
            case .text(let textBlock):
                try container.encode(textBlock)
            case .image(let imageBlock):
                try container.encode(imageBlock)
            case .toolUse(let toolUseBlock):
                try container.encode(toolUseBlock)
            case .thinking(let thinkingBlock):
                try container.encode(thinkingBlock)
            }
        }
    }
}

extension Anthropic.ContentBlock {
    public init(content: String) {
        self = .text(Anthropic.TextBlock(text: content, type: "text"))
    }

    public init(toolUseBlock: Anthropic.ToolUseBlock) {
        self = .toolUse(toolUseBlock)
    }

    public init(thinkingBlock: Anthropic.ThinkingBlock) {
        self = .thinking(thinkingBlock)
    }

    public var text: String {
        switch self {
        case .text(let text):
            return text.text
        case .image:
            return ""
        case .toolUse(let toolUse):
            return String(describing: toolUse)
        case .thinking(let thinking):
            return thinking.thinking
        }
    }

    public var isText: Bool {
        switch self {
        case .text:
            return true
        default:
            return false
        }
    }

    public var isToolUse: Bool {
        switch self {
        case .toolUse:
            return true
        default:
            return false
        }
    }

    public var isThinking: Bool {
        switch self {
        case .thinking:
            return true
        default:
            return false
        }
    }
}

extension Anthropic.ToolUseBlock {
    public var prettyInput: String {
        JSONFormatter.prettyString(from: input.toNativeDictionary) ?? String(describing: input)
    }
}
