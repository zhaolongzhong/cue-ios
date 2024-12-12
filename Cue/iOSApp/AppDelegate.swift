//
//  AppDelegate.swift
//

#if os(iOS)
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    @MainActor
    func application(_: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options _: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let sceneConfig = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        sceneConfig.delegateClass = SceneDelegate.self
        return sceneConfig
    }
}
#endif
