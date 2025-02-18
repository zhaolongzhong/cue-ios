import Foundation
import UserNotifications
import SwiftUI

@MainActor
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    @Published var notificationSettings: UNNotificationSettings?
    @Published var permissionGranted = false
    
    override private init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    func requestPermission() async {
        do {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            switch settings.authorizationStatus {
            case .notDetermined:
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                    options: [.alert, .badge, .sound]
                )
                permissionGranted = granted
            case .authorized:
                permissionGranted = true
            case .denied:
                permissionGranted = false
            case .provisional:
                permissionGranted = true
            case .ephemeral:
                permissionGranted = true
            @unknown default:
                permissionGranted = false
            }
            
            if permissionGranted {
                await registerForRemoteNotifications()
            }
            
            notificationSettings = settings
        } catch {
            permissionGranted = false
            print("Error requesting notification permission: \(error)")
        }
    }
    
    private func registerForRemoteNotifications() async {
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    func handleRemoteNotification(userInfo: [AnyHashable: Any]) {
        // Handle incoming notification
        guard let aps = userInfo["aps"] as? [String: Any],
              let alert = aps["alert"] as? [String: Any],
              let body = alert["body"] as? String else {
            return
        }
        
        // Post notification for other parts of the app to handle
        NotificationCenter.default.post(
            name: .remoteNotificationReceived,
            object: nil,
            userInfo: ["message": body]
        )
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Show notification when app is in foreground
        return [.banner, .sound, .badge]
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        // Handle notification tap
        let userInfo = response.notification.request.content.userInfo
        handleRemoteNotification(userInfo: userInfo)
    }
}