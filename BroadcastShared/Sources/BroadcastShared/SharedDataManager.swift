import Foundation
import os.log

public class SharedDataManager: @unchecked Sendable {
    public static let shared = SharedDataManager()
    private let userDefaults: UserDefaults
    private let logger = OSLog(subsystem: "ai.nextlabs.app.BroadcastShared", category: "DataManager")
    
    public let appGroupIdentifier = "group.ai.nextlabs.app.broadcast"
    
    public init() {
        os_log("📱 Initializing with group: %{public}@", log: logger, type: .info, appGroupIdentifier)
        // Use suiteName directly instead of any user
        if let defaults = UserDefaults(suiteName: appGroupIdentifier) {
            self.userDefaults = defaults
            os_log("✅ Initialized successfully", log: logger, type: .info)
        } else {
            os_log("❌ Failed to initialize UserDefaults", log: logger, type: .fault)
            fatalError("Could not initialize UserDefaults with app group")
        }
    }
    
    public func saveFrameData(width: Int, height: Int, frameCount: Int) {
        let frameData: [String: Any] = [
            "width": width,
            "height": height,
            "frameCount": frameCount,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // Write to defaults synchronously
        userDefaults.setValue(frameData, forKey: "lastFrameData")
        os_log("💾 Saved frame data: %{public}@", log: logger, type: .info, String(describing: frameData))
    }
    
    public func getLastFrameData() -> [String: Any]? {
        if let data = userDefaults.dictionary(forKey: "lastFrameData") {
            os_log("📖 Retrieved data: %{public}@", log: logger, type: .info, String(describing: data))
            return data
        }
        return nil
    }
}
