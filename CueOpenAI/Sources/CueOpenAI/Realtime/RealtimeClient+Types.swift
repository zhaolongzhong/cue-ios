public enum RealtimeTransport: Sendable {
    case webSocket
    case webRTC
}

public struct RealtimeConfig {
    let apiKey: String
    let model: String
}

public enum RealtimeConnectionState: Sendable {
    case connecting
    case connected
    case disconnected
    case error (String)
}

public enum RealtimeClientError: Error {
    case invalidConfiguration
    case failedToCreateSecret
    case invalidStringEncoding
    case unknownMessageType
    case decodingError
    case encodingError
    case invalidAudioData
    case disconnected
    case connectionError(Error)
    case generic(_ message: String? = nil)
    
    public var localizedDescription: String {
        switch self {
        case .invalidConfiguration:
            return "Failed to config the Realtime service"
        case .failedToCreateSecret:
            return "Failed to create client secret"
        case .invalidStringEncoding:
            return "Failed to encode message"
        case .unknownMessageType:
            return "Received unknown message type"
        case .decodingError:
            return "Failed to decode server event"
        case .encodingError:
            return "Failed to encode client event"
        case .invalidAudioData:
            return "Received invalid audio data"
        case .disconnected:
            return "Connection is disconnected"
        case .connectionError(let error):
            return "Connection error: \(error)"
        case .generic(let message):
            return "Generic error: \(message ?? "")"
        }
    }
}

public enum VoiceChatState: Equatable, Sendable {
    case idle // Initial state, no session
    case connecting // Session is being created or WebSocket is connecting
    case active // Actively chatting/recording
    case paused // Chat is paused but session is maintained
    case error(String) // Error state with message
    
    public var description: String {
        switch self {
        case .idle: return "Idle"
        case .connecting: return "Connecting"
        case .active: return "Active"
        case .paused: return "Paused"
        case .error(let message): return "Error: \(message)"
        }
    }
    
    public var isConnected: Bool {
        switch self {
            case .active, .paused: return true
            default: return false
        }
    }
}
