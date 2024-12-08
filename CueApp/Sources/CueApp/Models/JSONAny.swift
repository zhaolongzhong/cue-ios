import Foundation

// MARK: - JSONAny

class JSONAny: Codable {
    let value: Any

    static func decodingError(from codingPath: [CodingKey]) -> DecodingError {
        let context = DecodingError.Context(codingPath: codingPath, debugDescription: "Cannot decode JSONAny")
        return DecodingError.typeMismatch(JSONAny.self, context)
    }

    static func encodingError(for value: Any, codingPath: [CodingKey]) -> EncodingError {
        let context = EncodingError.Context(codingPath: codingPath, debugDescription: "Cannot encode JSONAny")
        return EncodingError.invalidValue(value, context)
    }

    init(_ value: Any) {
        self.value = value
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.value = NSNull()
        } else if let boolVal = try? container.decode(Bool.self) {
            self.value = boolVal
        } else if let intVal = try? container.decode(Int.self) {
            self.value = intVal
        } else if let doubleVal = try? container.decode(Double.self) {
            self.value = doubleVal
        } else if let stringVal = try? container.decode(String.self) {
            self.value = stringVal
        } else if var arrayContainer = try? decoder.unkeyedContainer() {
            var array: [Any] = []
            while !arrayContainer.isAtEnd {
                let jsonAny = try arrayContainer.decode(JSONAny.self)
                array.append(jsonAny.value)
            }
            self.value = array
        } else if let container = try? decoder.container(keyedBy: JSONCodingKey.self) {
            var dict = [String: Any]()
            for key in container.allKeys {
                let jsonAny = try container.decode(JSONAny.self, forKey: key)
                dict[key.stringValue] = jsonAny.value
            }
            self.value = dict
        } else {
            throw JSONAny.decodingError(from: decoder.codingPath)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self.value {
        case let boolVal as Bool:
            try container.encode(boolVal)
        case let intVal as Int:
            try container.encode(intVal)
        case let doubleVal as Double:
            try container.encode(doubleVal)
        case let stringVal as String:
            try container.encode(stringVal)
        case let arrayVal as [Any]:
            var arrayContainer = encoder.unkeyedContainer()
            for element in arrayVal {
                let jsonAny = JSONAny(element)
                try arrayContainer.encode(jsonAny)
            }
        case let dictVal as [String: Any]:
            var dictContainer = encoder.container(keyedBy: JSONCodingKey.self)
            for (key, value) in dictVal {
                let codingKey = JSONCodingKey(stringValue: key)!
                let jsonAny = JSONAny(value)
                try dictContainer.encode(jsonAny, forKey: codingKey)
            }
        case is NSNull:
            try container.encodeNil()
        default:
            throw JSONAny.encodingError(for: self.value, codingPath: encoder.codingPath)
        }
    }
}

// MARK: - JSONCodingKey

struct JSONCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
}

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

extension JSONDecoder {
    static func debugPrint(_ data: Data) {
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
            let prettyData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
            if let prettyString = String(data: prettyData, encoding: .utf8) {
                AppLog.websocket.debug("📋 Decoded JSON Structure:\n\(prettyString)")
            }
        } catch {
            AppLog.websocket.error("Error pretty printing JSON: \(error)")
        }
    }
}
