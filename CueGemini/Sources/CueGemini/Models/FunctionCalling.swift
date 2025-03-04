/// https://github.com/google-gemini/generative-ai-swift/blob/main/Sources/GoogleAI/FunctionCalling.swift

import Foundation
import CueCommon /// For JSONObject

public typealias GeminiFunctionCall = FunctionCall

/// A predicted function call returned from the model.
public struct FunctionCall: Equatable, Sendable {
  public let id: String

  /// The name of the function to call.
  public let name: String

  /// The function parameters and values.
  public let args: JSONObject
}

/// A `Schema` object allows the definition of input and output data types.
///
/// These types can be objects, but also primitives and arrays. Represents a select subset of an
/// [OpenAPI 3.0 schema object](https://spec.openapis.org/oas/v3.0.3#schema).
public typealias GeminiSchema = Schema

public final class Schema: Sendable {
  /// The data type.
  public let type: DataType

  /// The format of the data.
  public let format: String?

  /// A brief description of the parameter.
  public let description: String?

  /// Indicates if the value may be null.
  public let nullable: Bool?

  /// Possible values of the element of type ``DataType/string`` with "enum" format.
  public let enumValues: [String]?

  /// Schema of the elements of type ``DataType/array``.
  public let items: Schema?

  /// Properties of type ``DataType/object``.
  public let properties: [String: Schema]?

  /// Required properties of type ``DataType/object``.
  public let requiredProperties: [String]?

  enum CodingKeys: String, CodingKey {
    case type
    case format
    case description
    case nullable
    case enumValues = "enum"
    case items
    case properties
    case requiredProperties = "required"
  }

  /// Constructs a new `Schema`.
  ///
  /// - Parameters:
  ///   - type: The data type.
  ///   - format: The format of the data; used only for primitive datatypes.
  ///     Supported formats:
  ///     - ``DataType/integer``: int32, int64
  ///     - ``DataType/number``: float, double
  ///     - ``DataType/string``: enum
  ///   - description: A brief description of the parameter; may be formatted as Markdown.
  ///   - nullable: Indicates if the value may be null.
  ///   - enumValues: Possible values of the element of type ``DataType/string`` with "enum" format.
  ///     For example, an enum `Direction` may be defined as `["EAST", NORTH", "SOUTH", "WEST"]`.
  ///   - items: Schema of the elements of type ``DataType/array``.
  ///   - properties: Properties of type ``DataType/object``.
  ///   - requiredProperties: Required properties of type ``DataType/object``.
  public init(type: DataType, format: String? = nil, description: String? = nil,
              nullable: Bool? = nil,
              enumValues: [String]? = nil, items: Schema? = nil,
              properties: [String: Schema]? = nil,
              requiredProperties: [String]? = nil) {
    self.type = type
    self.format = format
    self.description = description
    self.nullable = nullable
    self.enumValues = enumValues
    self.items = items
    self.properties = properties
    self.requiredProperties = requiredProperties
  }
}

/// A data type.
///
/// Contains the set of OpenAPI [data types](https://spec.openapis.org/oas/v3.0.3#data-types).
public enum DataType: String, Sendable {
  /// A `String` type.
  case string = "STRING"

  /// A floating-point number type.
  case number = "NUMBER"

  /// An integer type.
  case integer = "INTEGER"

  /// A boolean type.
  case boolean = "BOOLEAN"

  /// An array type.
  case array = "ARRAY"

  /// An object type.
  case object = "OBJECT"
}

/// Structured representation of a function declaration.
///
/// This `FunctionDeclaration` is a representation of a block of code that can be used as a ``Tool``
/// by the model and executed by the client.
public struct FunctionDeclaration: Sendable {
  /// The name of the function.
  public let name: String

  /// A brief description of the function.
  public let description: String

  /// Describes the parameters to this function; must be of type ``DataType/object``.
  public let parameters: Schema?

  /// Constructs a new `FunctionDeclaration`.
  ///
  /// - Parameters:
  ///   - name: The name of the function; must be a-z, A-Z, 0-9, or contain underscores and dashes,
  ///   with a maximum length of 63.
  ///   - description: A brief description of the function.
  ///   - parameters: Describes the parameters to this function; the keys are parameter names and
  ///   the values are ``Schema`` objects describing them.
  ///   - requiredParameters: A list of required parameters by name.
  public init(name: String, description: String, parameters: [String: Schema]?,
              requiredParameters: [String]? = nil) {
    self.name = name
    self.description = description
    self.parameters = Schema(
      type: .object,
      properties: parameters,
      requiredProperties: requiredParameters
    )
  }
}

/// Helper tools that the model may use to generate response.
///
/// A `Tool` is a piece of code that enables the system to interact with external systems to
/// perform an action, or set of actions, outside of knowledge and scope of the model.
public struct Tool: Sendable {
  /// A list of `FunctionDeclarations` available to the model.
  let functionDeclarations: [FunctionDeclaration]?

  /// Enables the model to execute code as part of generation.
  let codeExecution: CodeExecution?

  /// Constructs a new `Tool`.
  ///
  /// - Parameters:
  ///   - functionDeclarations: A list of `FunctionDeclarations` available to the model that can be
  ///   used for function calling.
  ///   The model or system does not execute the function. Instead the defined function may be
  ///   returned as a ``FunctionCall`` in ``ModelContent/Part/functionCall(_:)`` with arguments to
  ///   the client side for execution. The model may decide to call a subset of these functions by
  ///   populating ``FunctionCall`` in the response. The next conversation turn may contain a
  ///   ``FunctionResponse`` in ``ModelContent/Part/functionResponse(_:)`` with the
  ///   ``ModelContent/role`` "function", providing generation context for the next model turn.
  ///   - codeExecution: Enables the model to execute code as part of generation, if provided.
  public init(functionDeclarations: [FunctionDeclaration]? = nil,
              codeExecution: CodeExecution? = nil) {
    self.functionDeclarations = functionDeclarations
    self.codeExecution = codeExecution
  }
}

public typealias GeminiTool = Tool

/// Configuration for specifying function calling behavior.
public struct FunctionCallingConfig {
  /// Defines the execution behavior for function calling by defining the
  /// execution mode.
  public enum Mode: String {
    /// The default behavior for function calling. The model calls functions to answer queries at
    /// its discretion.
    case auto = "AUTO"

    /// The model always predicts a provided function call to answer every query.
    case any = "ANY"

    /// The model will never predict a function call to answer a query. This can also be achieved by
    /// not passing any tools to the model.
    case none = "NONE"
  }

  /// Specifies the mode in which function calling should execute. If
  /// unspecified, the default value will be set to AUTO.
  let mode: Mode?

  /// A set of function names that, when provided, limits the functions the model
  /// will call.
  ///
  /// This should only be set when the Mode is ANY. Function names
  /// should match [FunctionDeclaration.name]. With mode set to ANY, model will
  /// predict a function call from the set of function names provided.
  let allowedFunctionNames: [String]?

  public init(mode: FunctionCallingConfig.Mode? = nil, allowedFunctionNames: [String]? = nil) {
    self.mode = mode
    self.allowedFunctionNames = allowedFunctionNames
  }
}

/// Tool configuration for any `Tool` specified in the request.
public struct ToolConfig {
  let functionCallingConfig: FunctionCallingConfig?

  public init(functionCallingConfig: FunctionCallingConfig? = nil) {
    self.functionCallingConfig = functionCallingConfig
  }
}

/// Result output from a ``FunctionCall``.
///
/// Contains a string representing the `FunctionDeclaration.name` and a structured JSON object
/// containing any output from the function is used as context to the model. This should contain the
/// result of a ``FunctionCall`` made based on model prediction.
public struct FunctionResponse: Decodable, Equatable, Sendable {
  public let id: String

  /// The name of the function that was called.
  public let name: String

  /// The function's response.
  public let response: JSONObject

  /// Constructs a new `FunctionResponse`.
  ///
  /// - Parameters:
  ///   - name: The name of the function that was called.
  ///   - response: The function's response.
  public init(id: String, name: String, response: JSONObject) {
    self.id = id
    self.name = name
    self.response = response
  }
}

/// Tool that executes code generated by the model, automatically returning the result to the model.
///
/// This type has no fields. See ``ExecutableCode`` and ``CodeExecutionResult``, which are only
/// generated when using this tool.
public struct CodeExecution: Sendable {
  /// Constructs a new `CodeExecution` tool.
  public init() {}
}

/// Code generated by the model that is meant to be executed, and the result returned to the model.
///
/// Only generated when using the ``CodeExecution`` tool, in which case the code will automatically
/// be executed, and a corresponding ``CodeExecutionResult`` will also be generated.
public struct ExecutableCode: Equatable, Sendable {
  /// The programming language of the ``code``.
  public let language: String

  /// The code to be executed.
  public let code: String
}

/// Result of executing the ``ExecutableCode``.
///
/// Only generated when using the ``CodeExecution`` tool, and always follows a part containing the
/// ``ExecutableCode``.
public struct CodeExecutionResult: Equatable, Sendable {
  /// Possible outcomes of the code execution.
  public enum Outcome: String, Sendable {
    /// An unrecognized code execution outcome was provided.
    case unknown = "OUTCOME_UNKNOWN"
    /// Unspecified status; this value should not be used.
    case unspecified = "OUTCOME_UNSPECIFIED"
    /// Code execution completed successfully.
    case ok = "OUTCOME_OK"
    /// Code execution finished but with a failure; ``CodeExecutionResult/output`` should contain
    /// the failure details from `stderr`.
    case failed = "OUTCOME_FAILED"
    /// Code execution ran for too long, and was cancelled. There may or may not be a partial
    /// ``CodeExecutionResult/output`` present.
    case deadlineExceeded = "OUTCOME_DEADLINE_EXCEEDED"
  }

  /// Outcome of the code execution.
  public let outcome: Outcome

  /// Contains `stdout` when code execution is successful, `stderr` or other description otherwise.
  public let output: String
}

// MARK: - Codable Conformance

extension FunctionCall: Decodable {
    enum CodingKeys: CodingKey {
        case id
        case name
        case args
    }

    private static func generateId() -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let randomString = String((0..<4).map { _ in letters.randomElement()! })
        return "fc_\(randomString)"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Handle optional args
        if let decodedArgs = try container.decodeIfPresent(JSONObject.self, forKey: .args) {
            args = decodedArgs
        } else {
            args = JSONObject()
        }

        // Generate id with prefix
        id = Self.generateId()

        // Decode required name
        name = try container.decode(String.self, forKey: .name)
    }
}

extension FunctionCall: Encodable {}

extension FunctionDeclaration: Encodable {
  enum CodingKeys: String, CodingKey {
    case name
    case description
    case parameters
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(name, forKey: .name)
    try container.encode(description, forKey: .description)
    try container.encode(parameters, forKey: .parameters)
  }
}

extension Schema: Encodable {}

extension DataType: Encodable {}

extension Tool: Encodable {}

extension FunctionCallingConfig: Encodable {}

extension FunctionCallingConfig.Mode: Encodable {}

extension ToolConfig: Encodable {}

extension FunctionResponse: Encodable {}

extension CodeExecution: Encodable {}

extension ExecutableCode: Codable {}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension CodeExecutionResult.Outcome: Codable {
  public init(from decoder: any Decoder) throws {
    let value = try decoder.singleValueContainer().decode(String.self)
    guard let decodedOutcome = CodeExecutionResult.Outcome(rawValue: value) else {
      self = .unknown
      return
    }

    self = decodedOutcome
  }
}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension CodeExecutionResult: Codable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    outcome = try container.decode(Outcome.self, forKey: .outcome)
    output = try container.decodeIfPresent(String.self, forKey: .output) ?? ""
  }
}

extension FunctionCall {
    public var prettyArgs: String {
        JSONFormatter.prettyString(from: args.toNativeDictionary) ??
            args.map { "\($0): \($1)" }.joined(separator: ", ")
    }
}
