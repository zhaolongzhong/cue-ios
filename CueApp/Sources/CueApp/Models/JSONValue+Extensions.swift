import Foundation

extension JSONValue {
    var asString: String? {
        if case .string(let str) = self {
            return str
        }
        return nil
    }

    var asBool: Bool? {
        if case .bool(let value) = self {
            return value
        }
        return nil
    }

    var asInt: Int? {
        if case .int(let value) = self {
            return value
        }
        return nil
    }
}
