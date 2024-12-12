//
//  SceneDelegate.swift
//
#if os(iOS)
import CueApp
import SwiftUI

class SceneDelegate: NSObject, UIWindowSceneDelegate {
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

#endif
