import Foundation

public enum WebSocketError: Error, Equatable, Sendable {
    case connectionFailed(String)
    case receiveFailed(String)
    case messageDecodingFailed
    case unauthorized
    case generic(_ message: String? = nil)
    case unknown(_ message: String? = nil)

    var errorDescription: String {
        switch self {
        case .connectionFailed(let message):
            return "Connection Failed: \(message)"
        case .messageDecodingFailed:
            return "Failed to decode message"
        case .receiveFailed(let message):
            return "Receive Failed: \(message)"
        case .unauthorized:
            return "Unauthorized access"
        case .generic(let message):
            return message ?? "An error occurred"
        case .unknown(let message):
            return message ?? "An unknown error occurred"
        }
    }
}

public enum ConnectionState: Equatable, Sendable {
    case disconnected
    case connecting
    case connected
    case error(WebSocketError)

    var description: String {
        switch self {
        case .error(let error):
            return "Error: \(error)"
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting"
        case .disconnected:
            return "Disconnected"
        }
    }
}
