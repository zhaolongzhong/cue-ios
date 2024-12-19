import Foundation
import os.log

final class ScreenManager: NSObject, ScreenCaptureDelegate, @unchecked Sendable {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "LiveAPI",
                              category: "ScreenManager")
    private let provider: ScreenCaptureProvider

    weak var delegate: ScreenManagerDelegate?

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
        provider.delegate = self
    }

    // MARK: - ScreenCaptureDelegate
    func screenCaptureProvider(_ provider: ScreenCaptureProvider, didReceiveFrame data: Data) {
        delegate?.screenManager(self, didReceiveFrame: data)
    }

    func startCapturingScreen() async throws {
        print("inx screen manager startCapturing()")
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
