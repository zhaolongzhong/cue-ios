import Foundation
import os.log

final class ScreenManager: NSObject, @unchecked Sendable {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "LiveAPI",
                              category: "ScreenManager")
    private let provider: ScreenCaptureProvider
    
    weak var delegate: ScreenManagerDelegate? {
        didSet {
            provider.delegate = delegate
        }
    }
    
    override init() {
        #if os(iOS)
        self.provider = IOSScreenCaptureProvider()
        #elseif os(macOS)
        self.provider = MacScreenCaptureProvider()
        #else
        #error("Unsupported platform")
        #endif
        super.init()
        logger.debug("ScreenManager initialized")
    }
    
    func startCapturingScreen() async throws {
        try await provider.startCapturing()
    }
    
    func stopCapturing() async {
        await provider.stopCapturing()
    }
    
    func requestScreenCapturePermission() async -> Bool {
        return await provider.requestPermission()
    }
    
    func prepareForBackground() {
        provider.prepareForBackground()
    }
    
    func prepareForForeground() {
        provider.prepareForForeground()
    }
}