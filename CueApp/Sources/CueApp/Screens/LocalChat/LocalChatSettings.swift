import Foundation

struct LocalChatSettings {
    var baseURL: String
    var model: String
    
    static let `default` = LocalChatSettings(
        baseURL: "http://localhost:11434",
        model: "llama2"
    )
}

// For UserDefaults storage
extension LocalChatSettings: Codable {}