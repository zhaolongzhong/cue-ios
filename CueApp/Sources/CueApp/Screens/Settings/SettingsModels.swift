struct AppConfig: Codable, Equatable {
    let forceUpgrade: Bool
    let minimumSupportedVersion: String
    let currentVersion: String
    let appcastUrl: String?

    enum CodingKeys: String, CodingKey {
        case forceUpgrade = "force_upgrade"
        case minimumSupportedVersion = "minimum_supported_version"
        case currentVersion = "current_version"
        case appcastUrl = "appcast_url"
    }
}
