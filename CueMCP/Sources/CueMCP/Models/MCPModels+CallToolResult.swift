import Foundation
import CueCommon

// MARK: - Base Result Model

public struct MCPCallToolResult: Codable {
    public let content: [MCPContent]
    public let isError: Bool

    enum CodingKeys: String, CodingKey {
        case content
        case isError
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Handle isError as either bool or number
        if let boolValue = try? container.decode(Bool.self, forKey: .isError) {
            isError = boolValue
        } else if let numberValue = try? container.decode(Double.self, forKey: .isError) {
            isError = numberValue != 0
        } else {
            isError = false
        }

        // Decode content array with proper type discrimination
        content = try container.decode([MCPContent].self, forKey: .content)
    }
}

// MARK: - Content Models

public enum MCPContent: Codable {
    case text(MCPTextContent)
    case image(MCPImageContent)

    enum CodingKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "text":
            let textContent = try MCPTextContent(from: decoder)
            self = .text(textContent)
        case "image":
            let imageContent = try MCPImageContent(from: decoder)
            self = .image(imageContent)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type,
                                                 in: container,
                                                 debugDescription: "Unsupported content type: \(type)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let textContent):
            try textContent.encode(to: encoder)
        case .image(let imageContent):
            try imageContent.encode(to: encoder)
        }
    }
}

public struct MCPTextContent: Codable {
    public let type: String
    public let text: String
}

public struct MCPImageContent: Codable {
    let type: String
    let data: String
    let mimeType: String
}

// MARK: - Extensions
#if os(macOS)
extension MCPServerManager {
    public func callToolWithResult(_ server: String, name: String, arguments: [String: Any]) async throws -> MCPCallToolResult {
        let request = [
            "jsonrpc": "2.0",
            "id": 0,
            "method": "tools/call",
            "params": [
                "name": name,
                "arguments": arguments
            ]
        ] as [String: Any]

        let result: JSONValue = try await callTool(server: server, request: request)
        let jsonData = try JSONEncoder().encode(result)
        return try JSONDecoder().decode(MCPCallToolResult.self, from: jsonData)

    }
}
#endif
