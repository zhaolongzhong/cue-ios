import Foundation

public enum MaxTokens: Codable, Sendable {
    case integer(Int)
    case infinity
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            self = .integer(intVal)
            return
        }
        if let stringVal = try? container.decode(String.self), stringVal == "inf" {
            self = .infinity
            return
        }
        throw DecodingError.typeMismatch(MaxTokens.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected Int or 'inf'"))
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .integer(let val):
            try container.encode(val)
        case .infinity:
            try container.encode("inf")
        }
    }
}
