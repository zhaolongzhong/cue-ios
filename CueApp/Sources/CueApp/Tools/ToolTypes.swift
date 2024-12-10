import Foundation
import CueOpenAI

// Base protocol for tool parameters
protocol ToolParameters: Sendable {
    var schema: [String: Property] { get }
    var required: [String] { get }
}

// Generic local tool definition
protocol LocalTool: Sendable {
    var name: String { get }
    var description: String { get }
    var parameterDefinition: ToolParameters { get }
    func call(_ args: ToolArguments) async throws -> String
}

struct ToolArguments: Sendable {
    private let storage: [String: String]

    init(_ dictionary: [String: Any]) {
        self.storage = dictionary.mapValues { String(describing: $0) }
    }

    func getString(_ key: String) -> String? {
        return storage[key]
    }

    func toDictionary() -> [String: Any] {
        return storage as [String: Any]
    }
}

enum ToolError: LocalizedError {
    case toolNotFound(String)
    case invalidArguments(String)

    var errorDescription: String? {
        switch self {
        case .toolNotFound(let name):
            return "Tool not found: \(name)"
        case .invalidArguments(let message):
            return "Invalid arguments: \(message)"
        }
    }
}
