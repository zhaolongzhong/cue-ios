//
//  Anthropic+ToolResultContent.swift
//  CueAnthropic
//

extension Anthropic {
    // MARK: - ToolResultContent
    public struct ToolResultContent: Codable, Sendable {
        public let isError: Bool
        public let toolUseId: String
        public let type: String  // This should be "tool_result"
        public let content: [ContentBlock]

        public enum CodingKeys: String, CodingKey {
            case isError = "is_error"
            case toolUseId = "tool_use_id"
            case type
            case content
        }

        public init(
            isError: Bool,
            toolUseId: String,
            type: String,
            content: [ContentBlock]
        ) {
            self.isError = isError
            self.toolUseId = toolUseId
            self.type = type
            self.content = content
        }
    }

    public enum ResultContentBlock: Codable, Sendable {
        case text(TextBlock)
        case imageBlock(ImageBlock)

        private enum CodingKeys: String, CodingKey {
            case type
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)

            switch type {
            case "text":
                let block = try TextBlock(from: decoder)
                self = .text(block)
            case "tool_use":
                let block = try ImageBlock(from: decoder)
                self = .imageBlock(block)
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .type,
                    in: container,
                    debugDescription: "Unknown type value: \(type)"
                )
            }
        }

        public func encode(to encoder: Encoder) throws {
            switch self {
            case .text(let block):
                try block.encode(to: encoder)
            case .imageBlock(let block):
                try block.encode(to: encoder)
            }
        }

        public init(content: String) {
            self = .text(TextBlock(text: content, type: "text"))
        }

        public var text: String {
            switch self {
            case .text(let text):
                return text.text
            case .imageBlock:
                return String(describing: "image")
            }
        }
    }
}
