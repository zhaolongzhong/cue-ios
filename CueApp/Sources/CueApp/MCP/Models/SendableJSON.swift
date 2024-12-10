import Foundation

// Define a Sendable enum to represent our JSON values
enum SendableJSON: Sendable, Hashable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case array([SendableJSON])
    case dictionary([String: SendableJSON])

    init(_ value: Any) {
        if let string = value as? String {
            self = .string(string)
        } else if let number = value as? NSNumber {
            self = .number(number.doubleValue)
        } else if let bool = value as? Bool {
            self = .bool(bool)
        } else if let dict = value as? [String: Any] {
            let sendableDict = dict.compactMapValues { SendableJSON($0) }
            self = .dictionary(sendableDict)
        } else if let array = value as? [Any] {
            let sendableArray = array.map { SendableJSON($0) }
            self = .array(sendableArray)
        } else {
            self = .null
        }
    }
}

// Helper function to convert SendableJSON to dictionary
func convertToDict(_ json: SendableJSON) -> Any {
    switch json {
    case .string(let str):
        return str
    case .number(let num):
        return num
    case .bool(let bool):
        return bool
    case .null:
        return NSNull()
    case .array(let arr):
        return arr.map { convertToDict($0) }
    case .dictionary(let dict):
        return dict.mapValues { convertToDict($0) }
    }
}
