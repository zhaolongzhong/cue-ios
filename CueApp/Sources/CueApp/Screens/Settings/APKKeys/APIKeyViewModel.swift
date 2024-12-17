import SwiftUI
import Combine

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

// MARK: - APIKeysViewModel
public class APIKeysViewModel: ObservableObject {
    @Published private(set) var openAIKey: String = ""
    @Published private(set) var anthropicKey: String = ""
    @Published private(set) var geminiKey: String = ""

    @Published var editingKeyType: APIKeyType?
    @Published var isAlertPresented: Bool = false
    @Published var tempAPIKey: String = ""

    private var cancellables = Set<AnyCancellable>()

    public init() {
        loadAPIKeys()
        setupObservers()
    }

    private func setupObservers() {
        // Observe changes for each key
        $openAIKey
            .dropFirst()
            .sink { [weak self] newKey in
                self?.saveKey(.openai, value: newKey)
            }
            .store(in: &cancellables)

        $anthropicKey
            .dropFirst()
            .sink { [weak self] newKey in
                self?.saveKey(.anthropic, value: newKey)
            }
            .store(in: &cancellables)

        $geminiKey
            .dropFirst()
            .sink { [weak self] newKey in
                self?.saveKey(.gemini, value: newKey)
            }
            .store(in: &cancellables)
    }

    private func loadAPIKeys() {
        openAIKey = UserDefaults.standard.string(forKey: APIKeyType.openai.rawValue) ?? ""
        anthropicKey = UserDefaults.standard.string(forKey: APIKeyType.anthropic.rawValue) ?? ""
        geminiKey = UserDefaults.standard.string(forKey: APIKeyType.gemini.rawValue) ?? ""
    }

    private func saveKey(_ keyType: APIKeyType, value: String) {
        if value.isEmpty {
            UserDefaults.standard.removeObject(forKey: keyType.rawValue)
        } else {
            UserDefaults.standard.set(value, forKey: keyType.rawValue)
        }
        print("Saved key for \(keyType.displayName): \(value.isEmpty ? "empty" : "set")")
    }

    public func getAPIKey(for keyType: APIKeyType) -> String? {
        switch keyType {
        case .openai: return openAIKey.isEmpty ? nil : openAIKey
        case .anthropic: return anthropicKey.isEmpty ? nil : anthropicKey
        case .gemini: return geminiKey.isEmpty ? nil : geminiKey
        }
    }

    func updateAPIKey(_ keyType: APIKeyType, with value: String) {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        switch keyType {
        case .openai:
            openAIKey = trimmedValue
        case .anthropic:
            anthropicKey = trimmedValue
        case .gemini:
            geminiKey = trimmedValue
        }
    }

    func startEditing(_ keyType: APIKeyType) {
        editingKeyType = keyType
        tempAPIKey = getAPIKey(for: keyType) ?? ""
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
