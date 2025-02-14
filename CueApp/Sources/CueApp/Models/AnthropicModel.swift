import Foundation

public enum AnthropicModel: String, CaseIterable {
    case claude3Haiku = "claude-3-haiku-20240307"
    case claude3Opus = "claude-3-opus-20240229"
    case claude3Sonnet = "claude-3-sonnet-20240229"
    case claude2_1 = "claude-2.1"
    case claude2 = "claude-2"
    
    public var displayName: String {
        switch self {
        case .claude3Haiku:
            return "Claude 3 Haiku"
        case .claude3Opus:
            return "Claude 3 Opus"
        case .claude3Sonnet:
            return "Claude 3 Sonnet"
        case .claude2_1:
            return "Claude 2.1"
        case .claude2:
            return "Claude 2"
        }
    }
    
    public var id: String {
        return rawValue
    }
}