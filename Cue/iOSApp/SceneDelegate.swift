//
//  SceneDelegate.swift
//
#if os(iOS)
import CueApp
import SwiftUI

class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, didUpdate previousCoordinateSpace: UICoordinateSpace, interfaceOrientation previousInterfaceOrientation: UIInterfaceOrientation, traitCollection previousTraitCollection: UITraitCollection) {
        if let colorSchemeSetting = UserDefaults.standard.string(forKey: "colorScheme"),
           let option = ColorSchemeOption(rawValue: colorSchemeSetting) {
            let style: UIUserInterfaceStyle = {
                switch option {
                case .system: return .unspecified
                case .light: return .light
                case .dark: return .dark
                }
            }()
            windowScene.windows.first?.overrideUserInterfaceStyle = style
        }
    }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let windowScene = scene as? UIWindowScene,
           let colorSchemeSetting = UserDefaults.standard.string(forKey: "colorScheme"),
           let option = ColorSchemeOption(rawValue: colorSchemeSetting) {
            let style: UIUserInterfaceStyle = {
                switch option {
                case .system: return .unspecified
                case .light: return .light
                case .dark: return .dark
                }
            }()
            windowScene.windows.first?.overrideUserInterfaceStyle = style
            windowScene.windows.first?.tintColor = .systemBlue.withAlphaComponent(0.5)
        }
    }

    @MainActor
    func sceneDidEnterBackground(_: UIScene) {
        AppLog.log.debug("sceneDidEnterBackground")
        NotificationCenter.default.post(name: .appDidEnterBackground, object: nil)
    }

    @MainActor
    func sceneWillEnterForeground(_: UIScene) {
        AppLog.log.debug("sceneWillEnterForeground")
        NotificationCenter.default.post(name: .appWillEnterForeground, object: nil)
    }
}

enum ColorSchemeOption: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
}

#endif
