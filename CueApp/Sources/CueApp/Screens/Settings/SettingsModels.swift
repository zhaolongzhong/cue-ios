struct AppConfig: Codable, Equatable {
    let forceUpgrade: Bool
    let minimumSupportedVersion: String
    let currentVersion: String
    let appcastUrl: String?
}
