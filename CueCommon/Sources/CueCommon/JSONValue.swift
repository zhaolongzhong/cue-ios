
/// https://github.com/google-gemini/generative-ai-swift/blob/main/Sources/GoogleAI/JSONValue.swift
import Foundation

/// A collection of name-value pairs representing a JSON object.
///
/// This may be decoded from, or encoded to, a
/// [`google.protobuf.Struct`](https://protobuf.dev/reference/protobuf/google.protobuf/#struct).
public typealias JSONObject = [String: JSONValue]

/// Represents a value in one of JSON's data types.
///
/// This may be decoded from, or encoded to, a
/// [`google.protobuf.Value`](https://protobuf.dev/reference/protobuf/google.protobuf/#value).
public enum JSONValue: Sendable, Hashable {
  /// A `null` value.
  case null

  /// A int value.
  case int(Int)

  /// A numeric value.
  case number(Double)

  /// A string value.
  case string(String)

  /// A boolean value.
  case bool(Bool)

  /// A JSON object.
  case object(JSONObject)

  /// An array of `JSONValue`s.
  case array([JSONValue])
}

extension JSONValue: Decodable {
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
    } else if let numberValue = try? container.decode(Int.self) {
      self = .int(numberValue)
    } else if let numberValue = try? container.decode(Double.self) {
      self = .number(numberValue)
    } else if let stringValue = try? container.decode(String.self) {
      self = .string(stringValue)
    } else if let boolValue = try? container.decode(Bool.self) {
      self = .bool(boolValue)
    } else if let objectValue = try? container.decode(JSONObject.self) {
      self = .object(objectValue)
    } else if let arrayValue = try? container.decode([JSONValue].self) {
      self = .array(arrayValue)
    } else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Failed to decode JSON value."
      )
    }
  }
}

extension JSONValue: Encodable {
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .null:
      try container.encodeNil()
    case let .int(stringValue):
      try container.encode(stringValue)
    case let .number(numberValue):
      // Convert to `Decimal` before encoding for consistent floating-point serialization across
      // platforms. E.g., `Double` serializes 3.14159 as 3.1415899999999999 in some cases and
      // 3.14159 in others. See
      // https://forums.swift.org/t/jsonencoder-encodable-floating-point-rounding-error/41390/4 for
      // more details.
      try container.encode(Decimal(numberValue))
    case let .string(stringValue):
      try container.encode(stringValue)
    case let .bool(boolValue):
      try container.encode(boolValue)
    case let .object(objectValue):
      try container.encode(objectValue)
    case let .array(arrayValue):
      try container.encode(arrayValue)
    }
  }
}

extension JSONValue: Equatable {}

