import Foundation

public enum ConnectionError: Error, Equatable {
    case invalidURL
    case connectionFailed(String)
    case receiveFailed(String)
}

public enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case error(ConnectionError)

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
