import SwiftUI

@MainActor
public final class APIKeysViewModel: ObservableObject {
    @Published private(set) var openAIKey: String = ""
    @Published private(set) var anthropicKey: String = ""
    @Published private(set) var geminiKey: String = ""

    @Published private(set) var editingKeyType: APIKeyType?
    @Published private(set) var isAlertPresented: Bool = false
    @Published var tempAPIKey: String = ""

    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        openAIKey = userDefaults.string(forKey: APIKeyType.openai.rawValue) ?? ""
        anthropicKey = userDefaults.string(forKey: APIKeyType.anthropic.rawValue) ?? ""
        geminiKey = userDefaults.string(forKey: APIKeyType.gemini.rawValue) ?? ""
    }

    private func saveKey(_ keyType: APIKeyType, value: String) {
        if value.isEmpty {
            userDefaults.removeObject(forKey: keyType.rawValue)
        } else {
            userDefaults.set(value, forKey: keyType.rawValue)
        }
        print("Saved key for \(keyType.displayName): \(value.isEmpty ? "empty" : "set")")
    }

    public func getAPIKey(for keyType: APIKeyType) -> String {
        switch keyType {
        case .openai: return openAIKey
        case .anthropic: return anthropicKey
        case .gemini: return geminiKey
        }
    }

    func updateAPIKey(_ keyType: APIKeyType, with value: String) {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        switch keyType {
        case .openai:
            openAIKey = trimmedValue
            saveKey(.openai, value: trimmedValue)
        case .anthropic:
            anthropicKey = trimmedValue
            saveKey(.anthropic, value: trimmedValue)
        case .gemini:
            geminiKey = trimmedValue
            saveKey(.gemini, value: trimmedValue)
        }
    }

    func startEditing(_ keyType: APIKeyType) {
        editingKeyType = keyType
        tempAPIKey = getAPIKey(for: keyType)
        isAlertPresented = true
    }

    func saveKey() {
        guard let keyType = editingKeyType else { return }
        updateAPIKey(keyType, with: tempAPIKey)
        stopEditing()
    }

    func cancelEditing() {
        tempAPIKey = ""
        stopEditing()
    }

    private func stopEditing() {
        editingKeyType = nil
        isAlertPresented = false
    }

    func deleteKey(_ keyType: APIKeyType) {
        updateAPIKey(keyType, with: "")
    }
}

// MARK: - APIKeyType Enum
public enum APIKeyType: String, CaseIterable, Identifiable {
    case openai = "OPENAI_API_KEY"
    case anthropic = "ANTHROPIC_API_KEY"
    case gemini = "GEMINI_API_KEY"

    public  var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .gemini: return "Google Gemini"
        }
    }

    var placeholder: String {
        switch self {
        case .openai: return "sk-..."
        case .anthropic: return "sk-ant-..."
        case .gemini: return "..."
        }
    }
}
