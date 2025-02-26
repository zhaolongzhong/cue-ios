import Foundation

enum AppEnvironment {
    case development
    case staging
    case production

    static var current: AppEnvironment {
        #if DEBUG
        return .development
        #elseif STAGING
        return .staging
        #else
        return .production
        #endif
    }
}

protocol URLConfiguration: Sendable {
    var baseAPIURL: String { get }
    var baseWebSocketURL: String { get }
}

final class EnvironmentConfig: URLConfiguration, Sendable {
    private let baseURLValue: String
    private let baseAPIURLValue: String
    private let baseWebSocketURLValue: String
    private let clientIdKey = "CLIENT_ID"
    let clientId: String

    init(domain: String) {
        let scheme = domain.contains("localhost") || domain.starts(with: "192") ? "http" : "https"
        let wsScheme = domain.contains("localhost") || domain.starts(with: "192") ? "ws" : "wss"

        let normalizedDomain = domain.contains("localhost")
            ? domain.replacingOccurrences(of: "localhost", with: "127.0.0.1")
            : domain

        // Construct the base URLs
        self.baseURLValue = "\(scheme)://\(normalizedDomain)"
        self.baseAPIURLValue = "\(scheme)://\(normalizedDomain)/api/v1"
        self.baseWebSocketURLValue = "\(wsScheme)://\(normalizedDomain)/api/v1/ws"

        // Initialize clientId
        if let existingClientId = UserDefaults.standard.string(forKey: clientIdKey) {
            self.clientId = existingClientId
        } else {
            let newClientId = UUID().uuidString
            UserDefaults.standard.set(newClientId, forKey: clientIdKey)
            self.clientId = newClientId
        }
    }

    var baseURL: String { baseURLValue }
    var baseAPIURL: String { baseAPIURLValue }
    var baseWebSocketURL: String { baseWebSocketURLValue }

    static func createProductionConfig() -> EnvironmentConfig {
        do {
            let domain: String = try AppConfiguration.value(for: "BASE_URL")
            // BASE_URL in Debug.xcconfig or Release.xcconfig must be url without scheme and double quote
            return EnvironmentConfig(domain: domain)
        } catch {
            fatalError("BASE_URL configuration is missing or invalid.")
        }
    }
}

extension EnvironmentConfig {
    // For testing
    nonisolated(unsafe) private static var _shared: EnvironmentConfig?

    static var shared: EnvironmentConfig {
        get {
            if _shared == nil {
                _shared = createProductionConfig()
            }
            return _shared!
        }
        set {
            _shared = newValue
        }
    }

    static var getBaseAPIURL: String {
        shared.baseAPIURL
    }

    static var getBaseWebSocketURL: String {
        shared.baseWebSocketURL
    }

    static var getClientId: String {
        shared.clientId
    }

    // Helper method to reset shared instance
    static func resetShared() {
        _shared = nil
    }
}
