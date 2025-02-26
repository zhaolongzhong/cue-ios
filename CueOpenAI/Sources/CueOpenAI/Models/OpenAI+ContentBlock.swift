import Foundation

extension OpenAI {
    public enum ContentBlockType: String, Codable, Equatable, Sendable {
        case text
        case imageUrl = "image_url"
    }

    public struct ImageURL: Codable, Equatable, Sendable {
        public let url: String

        public init(url: String) {
            self.url = url
        }
    }

    public enum ContentBlock: Codable, Equatable, Sendable {
        case text(String)
        case imageUrl(ImageURL)

        public var type: ContentBlockType {
            switch self {
            case .text: return .text
            case .imageUrl: return .imageUrl
            }
        }

        // Custom coding keys for encoding/decoding
        private enum CodingKeys: String, CodingKey {
            case type
            case text
            case imageUrl = "image_url"
        }

        // Custom encoding
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case .text(let textValue):
                try container.encode(ContentBlockType.text, forKey: .type)
                try container.encode(textValue, forKey: .text)
            case .imageUrl(let imageUrlValue):
                try container.encode(ContentBlockType.imageUrl, forKey: .type)
                try container.encode(imageUrlValue, forKey: .imageUrl)
            }
        }

        // Custom decoding
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(ContentBlockType.self, forKey: .type)

            switch type {
            case .text:
                let textValue = try container.decode(String.self, forKey: .text)
                self = .text(textValue)
            case .imageUrl:
                let imageUrlValue = try container.decode(ImageURL.self, forKey: .imageUrl)
                self = .imageUrl(imageUrlValue)
            }
        }
    }
}
