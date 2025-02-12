import SwiftUI

public enum UserDefaultsKeys {
    // Window state
    public static let windowOriginX = "windowOriginX"
    public static let windowOriginY = "windowOriginY"
    public static let windowWidth = "windowWidth"
    public static let windowHeight = "windowHeight"

    // Authentication
    public static let accessToken = "ACCESS_TOKEN_KEY"
    public static let refreshToken = "REFRESH_TOKEN_KEY"

    // Add any other UserDefaults keys here

    public static let allWindowKeys: [String] = [
        windowOriginX,
        windowOriginY,
        windowWidth,
        windowHeight
    ]

    public static let allAuthKeys: [String] = [
        accessToken,
        refreshToken
    ]
}
