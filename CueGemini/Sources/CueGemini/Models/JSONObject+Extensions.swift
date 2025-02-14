import Foundation

// MARK: - JSONValue Conversion Extensions
public extension JSONValue {
    /// Converts JSONValue to Swift's native type (Any)
    var toNative: Any {
        switch self {
        case .null:
            return NSNull()
        case .number(let num):
            return num
        case .string(let str):
            return str
        case .bool(let bool):
            return bool
        case .array(let arr):
            return arr.map { $0.toNative }
        case .object(let obj):
            return obj.mapValues { $0.toNative }
        }
    }
    
    /// Initialize from Swift native type
    init?(from value: Any) {
        switch value {
        case is NSNull:
            self = .null
        case let num as Double:
            self = .number(num)
        case let str as String:
            self = .string(str)
        case let bool as Bool:
            self = .bool(bool)
        case let arr as [Any]:
            let converted = arr.compactMap { JSONValue(from: $0) }
            guard converted.count == arr.count else { return nil }
            self = .array(converted)
        case let dict as [String: Any]:
            var converted: [String: JSONValue] = [:]
            for (key, value) in dict {
                guard let jsonValue = JSONValue(from: value) else { return nil }
                converted[key] = jsonValue
            }
            self = .object(converted)
        default:
            // Handle numeric types conversion
            if let number = value as? NSNumber {
                if CFGetTypeID(number) == CFBooleanGetTypeID() {
                    self = .bool(number.boolValue)
                } else {
                    self = .number(number.doubleValue)
                }
            } else {
                return nil
            }
        }
    }
}

// MARK: - Dictionary Extensions
public extension Dictionary where Key == String, Value == JSONValue {
    /// Converts JSONObject to [String: Any]
    var toNativeDictionary: [String: Any] {
        return self.mapValues { $0.toNative }
    }
    
    /// Initialize from [String: Any]
    init?(fromNative dictionary: [String: Any]) {
        var result: [String: JSONValue] = [:]
        
        for (key, value) in dictionary {
            guard let jsonValue = JSONValue(from: value) else {
                return nil
            }
            result[key] = jsonValue
        }
        
        self = result
    }
}

// MARK: - Error Handling
extension JSONValue {
    /// Attempts to get a string value
    public func getString() throws -> String {
        guard case .string(let value) = self else {
            throw JSONValueError.typeMismatch(expected: "String", actual: String(describing: self))
        }
        return value
    }
    
    /// Attempts to get a number value
    public func getNumber() throws -> Double {
        guard case .number(let value) = self else {
            throw JSONValueError.typeMismatch(expected: "Number", actual: String(describing: self))
        }
        return value
    }
    
    /// Attempts to get a boolean value
    public func getBool() throws -> Bool {
        guard case .bool(let value) = self else {
            throw JSONValueError.typeMismatch(expected: "Bool", actual: String(describing: self))
        }
        return value
    }
    
    /// Attempts to get an array value
    public func getArray() throws -> [JSONValue] {
        guard case .array(let value) = self else {
            throw JSONValueError.typeMismatch(expected: "Array", actual: String(describing: self))
        }
        return value
    }
    
    /// Attempts to get an object value
    public func getObject() throws -> JSONObject {
        guard case .object(let value) = self else {
            throw JSONValueError.typeMismatch(expected: "Object", actual: String(describing: self))
        }
        return value
    }
}

// MARK: - Error Types
public enum JSONValueError: Error {
    case typeMismatch(expected: String, actual: String)
}
