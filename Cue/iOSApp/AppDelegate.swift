//
//  AppDelegate.swift
//

#if os(iOS)
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    @MainActor
    func application(_ application: UIApplication,
                    configurationForConnecting connectingSceneSession: UISceneSession,
                    options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let sceneConfig = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        sceneConfig.delegateClass = SceneDelegate.self
        return sceneConfig
    }
}
#endif
