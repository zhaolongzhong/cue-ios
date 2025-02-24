import SwiftUI

@MainActor
public final class ProvidersViewModel: ObservableObject {
    @Published private(set) var openAIKey: String = ""
    @Published private(set) var anthropicKey: String = ""
    @Published private(set) var geminiKey: String = ""

    @Published private(set) var editingProvider: Provider?
    @Published private(set) var isAlertPresented: Bool = false
    @Published var tempAPIKey: String = ""

    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        openAIKey = userDefaults.string(forKey: Provider.openai.rawValue) ?? ""
        anthropicKey = userDefaults.string(forKey: Provider.anthropic.rawValue) ?? ""
        geminiKey = userDefaults.string(forKey: Provider.gemini.rawValue) ?? ""
    }

    private func saveKey(_ keyType: Provider, value: String) {
        if value.isEmpty {
            userDefaults.removeObject(forKey: keyType.rawValue)
        } else {
            userDefaults.set(value, forKey: keyType.rawValue)
        }
        print("Saved key for \(keyType.displayName): \(value.isEmpty ? "empty" : "set")")
    }

    public func getAPIKey(for keyType: Provider) -> String {
        switch keyType {
        case .openai: return openAIKey
        case .anthropic: return anthropicKey
        case .gemini: return geminiKey
        default:
            return ""
        }
    }

    func updateAPIKey(_ keyType: Provider, with value: String) {
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
        default:
            break
        }
    }

    func startEditing(_ keyType: Provider) {
        editingProvider = keyType
        tempAPIKey = getAPIKey(for: keyType)
        isAlertPresented = true
    }

    func saveKey() {
        guard let keyType = editingProvider else { return }
        updateAPIKey(keyType, with: tempAPIKey)
        stopEditing()
    }

    func cancelEditing() {
        tempAPIKey = ""
        stopEditing()
    }

    private func stopEditing() {
        editingProvider = nil
        isAlertPresented = false
    }

    func deleteKey(_ keyType: Provider) {
        updateAPIKey(keyType, with: "")
    }

    func isProviderEnabled(_ provider: Provider) -> Bool {
        !getAPIKey(for: provider).isEmpty
    }

    var enabledProviders: [Provider] {
        do {
            var providers = try [.openai, .anthropic, .gemini].filter(isProviderEnabled)
            providers.append(.local)
            return providers
        } catch {
            debugPrint("Error: \(error)")
        }
        return []
    }
}
