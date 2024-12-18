
import Foundation

public class SharedDataManager: @unchecked Sendable {
    public static let shared = SharedDataManager()
    private let userDefaults: UserDefaults
    
    public let appGroupIdentifier = "group.ai.nextlabs.app.broadcast"
    
    public init() {
        print("📱 SharedDataManager: initializing with group: \(appGroupIdentifier)")
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            print("❌ SharedDataManager: Failed to initialize UserDefaults")
            fatalError("Could not initialize UserDefaults with app group")
        }
        self.userDefaults = defaults
        print("✅ SharedDataManager: initialized successfully")
    }
    
    public func saveFrameData(width: Int, height: Int, frameCount: Int) {
        let frameData: [String: Any] = [
            "width": width,
            "height": height,
            "frameCount": frameCount,
            "timestamp": Date().timeIntervalSince1970
        ]
        print("💾 SharedDataManager: Saving frame data: \(frameData)")
        userDefaults.set(frameData, forKey: "lastFrameData")
        userDefaults.synchronize()
    }
    
    public func getLastFrameData() -> [String: Any]? {
        let data = userDefaults.dictionary(forKey: "lastFrameData")
        print("📖 SharedDataManager: Retrieved data: \(String(describing: data))")
        return data
    }
}
