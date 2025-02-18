import Foundation

/// Represents the current state of an agent's execution
public enum AgentState {
    case idle
    case thinking
    case executingTool(name: String)
    case stopped
    case error(String)
    
    public var description: String {
        switch self {
        case .idle:
            return "Ready"
        case .thinking:
            return "Thinking..."
        case .executingTool(let name):
            return "Using \(name.capitalized)"
        case .stopped:
            return "Stopped"
        case .error(let message):
            return "Error: \(message)"
        }
    }
}