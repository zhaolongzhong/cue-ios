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
    static let shared = EnvironmentConfig()

    private let baseAPIURLValue: String
    private let baseWebSocketURLValue: String
    private let clientIdKey = "CLIENT_ID"

    // MARK: - Properties
    let clientId: String

    // MARK: - Initialization
    private init() {
        do {
            // Retrieve BASE_URL using the generic method
            var domain: String = try Configuration.value(for: "BASE_URL")

            // Determine the schemes based on the domain
            let scheme = domain.contains("localhost") || domain.starts(with: "192") ? "http" : "https"
            let wsScheme = domain.contains("localhost") || domain.starts(with: "192") ? "ws" : "wss"

            if domain.contains("localhost") {
                domain = domain.replacingOccurrences(of: "localhost", with: "127.0.0.1")
            }

            // Construct the base URLs
            self.baseAPIURLValue = "\(scheme)://\(domain)/api/v1"
            self.baseWebSocketURLValue = "\(wsScheme)://\(domain)/api/v1/ws"

            // Initialize clientId
            if let existingClientId = UserDefaults.standard.string(forKey: clientIdKey) {
                self.clientId = existingClientId
            } else {
                let newClientId = UUID().uuidString
                UserDefaults.standard.set(newClientId, forKey: clientIdKey)
                self.clientId = newClientId
            }
        } catch {
            fatalError("BASE_URL configuration is missing or invalid.")
        }
    }

    // MARK: - URLConfiguration Implementation

    var baseAPIURL: String {
        baseAPIURLValue
    }

    var baseWebSocketURL: String {
        baseWebSocketURLValue
    }
}

extension EnvironmentConfig {
    static var getBaseAPIURL: String {
        shared.baseAPIURL
    }

    static var getBaseWebSocketURL: String {
        shared.baseWebSocketURL
    }

    static var getClientId: String {
        shared.clientId
    }
}
