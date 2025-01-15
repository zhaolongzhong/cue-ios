import Foundation
import Dependencies

protocol SettingsRepositoryProtocol: Sendable {
    func fetchAppConfig() async -> Result<AppConfig, Error>
}

actor SettingsRepository: SettingsRepositoryProtocol {
    @Dependency(\.settingsService) private var settingsService

    func fetchAppConfig() async -> Result<AppConfig, Error> {
        do {
            let config = try await settingsService.fetchConfiguration()
            return .success(config)
        } catch {
            return .failure(error)
        }
    }
}

// MARK: - Dependency Injection for SettingsRepository

extension SettingsRepository: DependencyKey {
    static let liveValue: SettingsRepositoryProtocol = SettingsRepository()
}

extension DependencyValues {
    var settingsRepository: SettingsRepositoryProtocol {
        get { self[SettingsRepository.self] }
        set { self[SettingsRepository.self] = newValue }
    }
}
