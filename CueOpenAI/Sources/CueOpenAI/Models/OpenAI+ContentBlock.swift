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

    public struct ContentBlock: Codable, Equatable, Sendable {
        public let type: ContentBlockType
        public let text: String?
        public let imageUrl: ImageURL?

        public init(type: ContentBlockType, text: String? = nil, imageUrl: ImageURL? = nil) {
            self.type = type
            self.text = text
            self.imageUrl = imageUrl
        }

        enum CodingKeys: String, CodingKey {
            case type
            case text
            case imageUrl = "image_url"
        }
    }
}
