import Foundation

public enum ChatModel: String, CaseIterable {
    case gpt4oMini = "gpt-4-0125-preview"
    case gpt4Turbo = "gpt-4-turbo-preview"
    case gpt4Vision = "gpt-4-vision-preview"
    case gpt35Turbo = "gpt-3.5-turbo-0125"
    case gpt4 = "gpt-4"
    
    public var displayName: String {
        switch self {
        case .gpt4oMini:
            return "GPT-4 Mini"
        case .gpt4Turbo:
            return "GPT-4 Turbo"
        case .gpt4Vision:
            return "GPT-4 Vision"
        case .gpt35Turbo:
            return "GPT-3.5 Turbo"
        case .gpt4:
            return "GPT-4"
        }
    }
    
    public var id: String {
        return rawValue
    }
}