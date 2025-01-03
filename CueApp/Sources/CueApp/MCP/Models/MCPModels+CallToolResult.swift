import Foundation

// MARK: - Base Result Model

struct MCPCallToolResult: Codable {
    let content: [MCPContent]
    let isError: Bool

    enum CodingKeys: String, CodingKey {
        case content
        case isError
    }

    init(from decoder: Decoder) throws {
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

enum MCPContent: Codable {
    case text(MCPTextContent)
    case image(MCPImageContent)

    enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
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

    func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let textContent):
            try textContent.encode(to: encoder)
        case .image(let imageContent):
            try imageContent.encode(to: encoder)
        }
    }
}

struct MCPTextContent: Codable {
    let type: String
    let text: String
}

struct MCPImageContent: Codable {
    let type: String
    let data: String
    let mimeType: String
}

// MARK: - Extensions
#if os(macOS)
extension MCPServerManager {
    func callToolWithResult(_ server: String, name: String, arguments: [String: Any]) async throws -> MCPCallToolResult {
        let request = [
            "jsonrpc": "2.0",
            "id": 0,
            "method": "tools/call",
            "params": [
                "name": name,
                "arguments": arguments
            ]
        ] as [String: Any]

        let result = try await callTool(server: server, request: request)
        let jsonData = try JSONSerialization.data(withJSONObject: convertToDict(result))
        return try JSONDecoder().decode(MCPCallToolResult.self, from: jsonData)
    }
}
#endif

// MARK: - Debug Helpers

extension MCPContent: CustomStringConvertible {
    var description: String {
        switch self {
        case .text(let content):
            return "Text: \(content.text)"
        case .image(let content):
            return "Image: \(content.mimeType) (\(content.data.prefix(20))...)"
        }
    }
}

extension MCPCallToolResult: CustomStringConvertible {
    var description: String {
        """
        Tool Result:
          Error: \(isError)
          Content:
        \(content.map { "    - \($0)" }.joined(separator: "\n"))
        """
    }
}
