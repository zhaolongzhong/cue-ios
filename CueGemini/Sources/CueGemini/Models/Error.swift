/// https://github.com/google-gemini/generative-ai-swift/blob/main/Sources/GoogleAI/Errors.swift

import Foundation

struct RPCError: Error {
  let httpResponseCode: Int
  let message: String
  let status: RPCStatus
  let details: [ErrorDetails]

  private var errorInfo: ErrorDetails? {
    return details.first { $0.isErrorInfo() }
  }

  init(httpResponseCode: Int, message: String, status: RPCStatus, details: [ErrorDetails]) {
    self.httpResponseCode = httpResponseCode
    self.message = message
    self.status = status
    self.details = details
  }

  func isInvalidAPIKeyError() -> Bool {
    return errorInfo?.reason == "API_KEY_INVALID"
  }

  func isUnsupportedUserLocationError() -> Bool {
    return message == RPCErrorMessage.unsupportedUserLocation.rawValue
  }
}

extension RPCError: Decodable {
  enum CodingKeys: CodingKey {
    case error
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let status = try container.decode(ErrorStatus.self, forKey: .error)

    if let code = status.code {
      httpResponseCode = code
    } else {
      httpResponseCode = -1
    }

    if let message = status.message {
      self.message = message
    } else {
      message = "Unknown error."
    }

    if let rpcStatus = status.status {
      self.status = rpcStatus
    } else {
      self.status = .unknown
    }

    details = status.details
  }
}

struct ErrorStatus {
  let code: Int?
  let message: String?
  let status: RPCStatus?
  let details: [ErrorDetails]
}

struct ErrorDetails {
  static let errorInfoType = "type.googleapis.com/google.rpc.ErrorInfo"

  let type: String
  let reason: String?
  let domain: String?

  func isErrorInfo() -> Bool {
    return type == ErrorDetails.errorInfoType
  }
}

extension ErrorDetails: Decodable, Equatable {
  enum CodingKeys: String, CodingKey {
    case type = "@type"
    case reason
    case domain
  }
}

extension ErrorStatus: Decodable {
  enum CodingKeys: CodingKey {
    case code
    case message
    case status
    case details
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    code = try container.decodeIfPresent(Int.self, forKey: .code)
    message = try container.decodeIfPresent(String.self, forKey: .message)
    do {
      status = try container.decodeIfPresent(RPCStatus.self, forKey: .status)
    } catch {
      status = .unknown
    }
    if container.contains(.details) {
      details = try container.decode([ErrorDetails].self, forKey: .details)
    } else {
      details = []
    }
  }
}

enum RPCStatus: String, Decodable {
  // Not an error; returned on success.
  case ok = "OK"

  // The operation was cancelled, typically by the caller.
  case cancelled = "CANCELLED"

  // Unknown error.
  case unknown = "UNKNOWN"

  // The client specified an invalid argument.
  case invalidArgument = "INVALID_ARGUMENT"

  // The deadline expired before the operation could complete.
  case deadlineExceeded = "DEADLINE_EXCEEDED"

  // Some requested entity (e.g., file or directory) was not found.
  case notFound = "NOT_FOUND"

  // The entity that a client attempted to create (e.g., file or directory) already exists.
  case alreadyExists = "ALREADY_EXISTS"

  // The caller does not have permission to execute the specified operation.
  case permissionDenied = "PERMISSION_DENIED"

  // The request does not have valid authentication credentials for the operation.
  case unauthenticated = "UNAUTHENTICATED"

  // Some resource has been exhausted, perhaps a per-user quota, or perhaps the entire file system
  // is out of space.
  case resourceExhausted = "RESOURCE_EXHAUSTED"

  // The operation was rejected because the system is not in a state required for the operation's
  // execution.
  case failedPrecondition = "FAILED_PRECONDITION"

  // The operation was aborted, typically due to a concurrency issue such as a sequencer check
  // failure or transaction abort.
  case aborted = "ABORTED"

  // The operation was attempted past the valid range.
  case outOfRange = "OUT_OF_RANGE"

  // The operation is not implemented or is not supported/enabled in this service.
  case unimplemented = "UNIMPLEMENTED"

  // Internal errors.
  case internalError = "INTERNAL"

  // The service is currently unavailable.
  case unavailable = "UNAVAILABLE"

  // Unrecoverable data loss or corruption.
  case dataLoss = "DATA_LOSS"
}

enum RPCErrorMessage: String {
  case unsupportedUserLocation = "User location is not supported for the API use."
}

enum InvalidCandidateError: Error {
  case emptyContent(underlyingError: Error)
  case malformedContent(underlyingError: Error)
}
