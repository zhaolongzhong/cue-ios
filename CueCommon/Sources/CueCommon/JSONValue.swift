import Foundation
/// https://github.com/google-gemini/generative-ai-swift/blob/main/Sources/GoogleAI/JSONValue.swift

public enum JSONValue: Codable, Sendable, Hashable {
    case null
    case bool(Bool)
    case string(String)
    case int(Int)
    case double(Double)
    case array([JSONValue])
    case dictionary([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else if let dict = try? container.decode([String: JSONValue].self) {
            self = .dictionary(dict)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unable to decode JSONValue")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .dictionary(let value):
            try container.encode(value)
        }
    }
}

extension JSONValue: Equatable {
    public static func == (lhs: JSONValue, rhs: JSONValue) -> Bool {
        switch (lhs, rhs) {
        case (.null, .null):
            return true
        case (.bool(let lhsValue), .bool(let rhsValue)):
            return lhsValue == rhsValue
        case (.string(let lhsValue), .string(let rhsValue)):
            return lhsValue == rhsValue
        case (.int(let lhsValue), .int(let rhsValue)):
            return lhsValue == rhsValue
        case (.double(let lhsValue), .double(let rhsValue)):
            return lhsValue == rhsValue
        case (.array(let lhsValue), .array(let rhsValue)):
            return lhsValue == rhsValue
        case (.dictionary(let lhsValue), .dictionary(let rhsValue)):
            return lhsValue == rhsValue
        default:
            return false
        }
    }
}

extension JSONValue {
    public var asString: String? {
        if case .string(let str) = self {
            return str
        }
        return nil
    }

    public var asBool: Bool? {
        if case .bool(let value) = self {
            return value
        }
        return nil
    }

    public var asInt: Int? {
        if case .int(let value) = self {
            return value
        }
        return nil
    }
}

extension JSONValue {
    public init<T: Encodable>(encodable value: T) throws {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(value)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self = try decoder.decode(JSONValue.self, from: data)
    }
}

extension JSONValue {
    public init(any value: Any) {
        if value is NSNull {
            self = .null
        } else if let string = value as? String {
            self = .string(string)
        } else if let bool = value as? Bool {
            self = .bool(bool)
        } else if let int = value as? Int {
            self = .int(int)
        } else if let double = value as? Double {
            self = .double(double)
        } else if let array = value as? [Any] {
            self = .array(array.map { JSONValue(any: $0) })
        } else if let dict = value as? [String: Any] {
            self = .dictionary(dict.mapValues { JSONValue(any: $0) })
        } else {
            self = .null
        }
    }
}

extension JSONDecoder {
    static func debugPrint(_ data: Data) {
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
            let prettyData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
            if let prettyString = String(data: prettyData, encoding: .utf8) {
                print("📋 Decoded JSON Structure:\n\(prettyString)")
            }
        } catch {
            print("Error pretty printing JSON: \(error)")
        }
    }
}
