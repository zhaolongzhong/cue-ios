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

struct ToolArguments {
    private let storage: [String: Any]

    init(_ dictionary: [String: Any]) {
        self.storage = dictionary
    }

    func getBool(_ key: String) -> Bool? {
        storage[key] as? Bool
    }

    func getString(_ key: String) -> String? {
        storage[key] as? String
    }

    func getInt(_ key: String) -> Int? {
        if let intValue = storage[key] as? Int {
            return intValue
        } else if let strValue = storage[key] as? String, let intValue = Int(strValue) {
            return intValue
        }
        return nil
    }

    func getArray(_ key: String) -> [Any]? {
        storage[key] as? [Any]
    }

    func toDictionary() -> [String: Any] {
        storage
    }
}

// Declare @unchecked Sendable conformance in an extension.
extension ToolArguments: @unchecked Sendable {}

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
