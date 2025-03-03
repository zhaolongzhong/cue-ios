import SwiftUI

public class ProviderDetailViewModel: ObservableObject {
    @Published var maxTurns: Int
    @Published var maxMessages: Int
    @Published var isStreamingEnabled: Bool
    @Published var isToolEnabled: Bool
    @Published var hasAPIKey: Bool = false
    @Published var showingAPIKeyAlert = false
    @Published var tempAPIKey: String = ""
    @Published var baseURL: String = ""
    @Published var showingBaseURLAlert = false
    @Published var tempBaseURL: String = ""

    private let provider: Provider
    private let defaults = UserDefaults.standard

    init(provider: Provider) {
        self.provider = provider

        // Load stored values using the type-safe accessors
        self.maxTurns = defaults.maxTurns(for: provider)
        self.maxMessages = defaults.maxMessages(for: provider)
        self.isStreamingEnabled = defaults.isStreamingEnabled(for: provider)
        self.isToolEnabled = defaults.isToolEnabled(for: provider)
        self.baseURL = defaults.baseURLWithDefault(for: provider)

        if provider.requiresAPIKey {
            self.hasAPIKey = defaults.hasAPIKey(for: provider)
            self.tempAPIKey = defaults.apiKey(for: provider) ?? ""
        }
    }

    func saveMaxMessages(_ value: Int) {
        guard value > 0 else { return }

        maxMessages = value
        defaults.setMaxMessages(value, for: provider)
    }

    func saveMaxTurns(_ value: Int) {
        guard value > 0 else { return }

        maxTurns = value
        defaults.setMaxTurns(value, for: provider)
    }

    func updateStreamingEnabled(_ value: Bool) {
        isStreamingEnabled = value
        defaults.setStreamingEnabled(value, for: provider)
    }

    func updateToolEnabled(_ value: Bool) {
        isToolEnabled = value
        defaults.setToolEnabled(value, for: provider)
    }

    func promptForAPIKey() {
        tempAPIKey = defaults.apiKey(for: provider) ?? ""
        showingAPIKeyAlert = true
    }

    func saveAPIKey() {
        if !tempAPIKey.isEmpty {
            defaults.setAPIKey(tempAPIKey, for: provider)
            hasAPIKey = true
        }
        showingAPIKeyAlert = false
    }

    func cancelAPIKeyEditing() {
        showingAPIKeyAlert = false
        tempAPIKey = defaults.apiKey(for: provider) ?? ""
    }

    func promptForBaseURL() {
        tempBaseURL = baseURL
        showingBaseURLAlert = true
    }

    func saveBaseURL() {
        let trimmed = tempBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)

        if let normalizedURL = trimmed.normalizedURLString() {
            baseURL = normalizedURL
            defaults.setBaseURL(normalizedURL, for: provider)
        } else if !trimmed.isEmpty {
            baseURL = trimmed
            defaults.setBaseURL(trimmed, for: provider)
        }

        showingBaseURLAlert = false
    }

    func cancelBaseURLEditing() {
        showingBaseURLAlert = false
        tempBaseURL = ""
    }

    func resetBaseURLToDefault() {
        defaults.removeObject(forKey: ProviderSettingsKeys.BaseURL.key(for: provider))
        baseURL = defaults.baseURLWithDefault(for: provider)
    }
}

extension String {
    var isValidURL: Bool {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme,
              !scheme.isEmpty else {
            return false
        }
        return true
    }

    func normalizedURLString() -> String? {
        // First check if it's already valid
        if self.isValidURL {
            return self
        }

        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.contains("://") {
            let withScheme = "http://" + trimmed
            if withScheme.isValidURL {
                return withScheme
            }
        }

        // Failed to normalize
        return nil
    }
}
