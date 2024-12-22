import Foundation

public struct ServerError: Codable, Sendable {
    public let eventId: String
    public let type: String
    public let error: ErrorDetail
}

public struct ErrorDetail: Codable, Sendable {
    public let type: String
    public let code: String?
    public let message: String
    public let param: String?
    public let eventId: String?
}
