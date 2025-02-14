import Foundation
import CueOpenAI

// Base protocol for tool parameters
protocol ToolParameters: Sendable {
    var schema: [String: OpenAIParametersProperty] { get }
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
    private let args: [String: Any]

    init(_ dictionary: [String: Any]) {
        self.args = dictionary
    }

    func getBool(_ key: String) -> Bool? {
        args[key] as? Bool
    }

    func getString(_ key: String) -> String? {
        args[key] as? String
    }

    func getInt(_ key: String) -> Int? {
        if let intValue = args[key] as? Int {
            return intValue
        } else if let doubleValue = args[key] as? Double {
            let intValue = Int(doubleValue)
            return intValue
        } else if let strValue = args[key] as? String, let intValue = Int(strValue) {
            return intValue
        }
        return nil
    }

    func getArray(_ key: String) -> [Any]? {
        args[key] as? [Any]
    }

    func toDictionary() -> [String: Any] {
        args
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
