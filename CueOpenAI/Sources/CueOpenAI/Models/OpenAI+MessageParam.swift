extension OpenAI {
    public struct MessageParam: Codable, Sendable {
        public let role: String
        public let content: ContentValue

        public init(role: String, content: ContentValue) {
            self.role = role
            self.content = content
        }

        public init(role: String, contentString: String) {
            self.role = role
            self.content = .string(contentString)
        }

        public init(role: String, contentBlocks: [ContentBlock]) {
            self.role = role
            self.content = .array(contentBlocks)
        }

        private enum CodingKeys: String, CodingKey {
            case role, content
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(role, forKey: .role)

            switch content {
            case .string(let stringContent):
                try container.encode(stringContent, forKey: .content)
            case .array(let contentBlocks):
                try container.encode(contentBlocks, forKey: .content)
            }
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            role = try container.decode(String.self, forKey: .role)

            if let stringContent = try? container.decode(String.self, forKey: .content) {
                content = .string(stringContent)
            } else if let contentBlocks = try? container.decode([ContentBlock].self, forKey: .content) {
                content = .array(contentBlocks)
            } else {
                throw DecodingError.dataCorruptedError(forKey: .content, in: container, debugDescription: "Content must be either a string or an array of content blocks")
            }
        }
    }

    public enum ContentValue: Codable, Equatable, Sendable {
        case string(String)
        case array([ContentBlock])

        public func encode(to encoder: Encoder) throws {
            switch self {
            case .string(let stringValue):
                var container = encoder.singleValueContainer()
                try container.encode(stringValue)
            case .array(let arrayValue):
                var container = encoder.singleValueContainer()
                try container.encode(arrayValue)
            }
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()

            if let stringValue = try? container.decode(String.self) {
                self = .string(stringValue)
            } else if let arrayValue = try? container.decode([ContentBlock].self) {
                self = .array(arrayValue)
            } else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Failed to decode content value")
            }
        }
    }
}

extension OpenAI.MessageParam {
    public var contentAsString: String {
        switch content {
        case .string(let stringContent):
            return stringContent
        case .array(let contentBlocks):
            return contentBlocks.compactMap { block -> String? in
                if block.type == .text, let text = block.text {
                    return text
                }
                return nil
            }.joined(separator: "\n")
        }
    }

    // Get image URLs from content blocks
    public var imageUrls: [String] {
        switch content {
        case .string:
            return []
        case .array(let contentBlocks):
            return contentBlocks.compactMap { block -> String? in
                if block.type == .imageUrl, let imageUrl = block.imageUrl {
                    return imageUrl.url
                }
                return nil
            }
        }
    }
}

extension OpenAI.ContentValue {
    public var contentAsString: String {
        switch self {
        case .string(let stringContent):
            return stringContent
        case .array(let contentBlocks):
            return contentBlocks.compactMap { block -> String? in
                if block.type == .text, let text = block.text {
                    return text
                }
                return nil
            }.joined(separator: "\n")
        }
    }
}
