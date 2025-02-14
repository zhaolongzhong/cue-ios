import Foundation

public typealias VoiceState = VoiceChatState

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

    public var canConnect: Bool {
        switch self {
        case .idle, .error: return true
        default: return false
        }
    }
}
