//
//  SceneDelegate.swift
//
#if os(iOS)
import SwiftUI
import CueApp

class SceneDelegate: NSObject, UIWindowSceneDelegate {
    @MainActor
    func sceneDidEnterBackground(_ scene: UIScene) {
        AppLog.log.debug("sceneDidEnterBackground")
        NotificationCenter.default.post(name: .appDidEnterBackground, object: nil)
    }

    @MainActor
    func sceneWillEnterForeground(_ scene: UIScene) {
        AppLog.log.debug("sceneWillEnterForeground")
        NotificationCenter.default.post(name: .appWillEnterForeground, object: nil)
    }
}

#endif
