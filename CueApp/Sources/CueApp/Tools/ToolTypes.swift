import Foundation
import CueOpenAI

// Generic local tool definition
public protocol LocalTool: Equatable, Sendable {
    var name: String { get }
    var description: String { get }
    var parameterDefinition: any ToolParameters { get }
    func call(_ args: ToolArguments) async throws -> String
}

// Base protocol for tool parameters
public protocol ToolParameters: Equatable, Sendable {
    var schema: [String: OpenAIParametersProperty] { get }
    var required: [String] { get }
}

public struct ToolArguments {
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
            return Int(doubleValue)
        }
        return nil
    }

    func getDouble(_ key: String) -> Double? {
        if let doubleValue = args[key] as? Double {
            return doubleValue
        } else if let intValue = args[key] as? Int {
            return Double(intValue)
        }
        return nil
    }

    func getArray(_ key: String) -> [Any]? {
        args[key] as? [Any]
    }

    func getIntArray(_ key: String) -> [Int]? {
        args[key] as? [Int]
    }

    func getStringArray(_ key: String) -> [String]? {
        args[key] as? [String]
    }

    func getBoolArray(_ key: String) -> [Bool]? {
        args[key] as? [Bool]
    }

    func getDoubleArray(_ key: String) -> [Double]? {
        args[key] as? [Double]
    }

    func getDictionary(_ key: String) -> [String: Any]? {
        return args[key] as? [String: Any]
    }

    func toDictionary() -> [String: Any] {
        return args
    }

    func hasKey(_ key: String) -> Bool {
        return args[key] != nil
    }

    func getAllKeys() -> [String] {
        return Array(args.keys)
    }
}

// Declare @unchecked Sendable conformance in an extension.
extension ToolArguments: @unchecked Sendable {}

enum ToolError: LocalizedError {
    case toolNotFound(String)
    case invalidArguments(String)
    case invalidState(String)
    case timeout(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .toolNotFound(let name):
            return "Tool not found: \(name)"
        case .invalidArguments(let message):
            return "Invalid arguments: \(message)"
        case .invalidState(let message):
            return "Invalid state: \(message)"
        case .timeout(let message):
            return "Timeout: \(message)"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
}

typealias CLIResult = ToolResult

struct ToolResult: Sendable {
    var output: String?
    var error: String?
    var base64_image: String?
    var system: String?

    init(output: String? = nil, error: String? = nil, base64_image: String? = nil, system: String? = nil) {
        self.output = output
        self.error = error
        self.base64_image = base64_image
        self.system = system
    }
}

extension ToolResult: CustomStringConvertible {
    var description: String {
        var result = ""

        if let output = output, !output.isEmpty {
            result += output
        }

        if let error = error, !error.isEmpty {
            if !result.isEmpty {
                result += "\n\nError:\n"
            } else {
                result += "Error:\n"
            }
            result += error
        }

        if let system = system, !system.isEmpty {
            if !result.isEmpty {
                result += "\n\n"
            }
            result += system
        }

        return result.isEmpty ? "No output" : result
    }
}
