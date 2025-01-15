import Foundation
import Dependencies
import os.log

protocol SettingsServiceProtocol: Sendable {
    func fetchConfiguration() async throws -> AppConfig
}

enum SettingsEndpoint {
    case configuration
}

extension SettingsEndpoint: Endpoint {
    var path: String {
        switch self {
        case .configuration:
            return "/settings/configuration"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .configuration:
            return .get
        }
    }

    var requiresAuth: Bool {
        return false
    }
}

struct SettingsService: SettingsServiceProtocol {
    private let networkClient: NetworkClientProtocol

    init(networkClient: NetworkClientProtocol) {
        self.networkClient = networkClient
    }

    func fetchConfiguration() async throws -> AppConfig {
        return try await networkClient.request(SettingsEndpoint.configuration)
    }
}

// MARK: - Dependency Injection for SettingsService

extension SettingsService: DependencyKey {
    static let liveValue: SettingsServiceProtocol = SettingsService(networkClient: NetworkClient.shared)
}

extension DependencyValues {
    var settingsService: SettingsServiceProtocol {
        get { self[SettingsService.self] }
        set { self[SettingsService.self] = newValue }
    }
}
