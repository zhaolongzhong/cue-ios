import Foundation
import os.log

public final class ScreenCaptureManager: NSObject, ScreenCaptureDelegate, @unchecked Sendable {
    private let logger = Logger(subsystem: "ScreenCaptureManager", category: "ScreenCaptureManager")
    private let provider: ScreenCaptureProvider

    public var events: AsyncThrowingStream<Data, Error>?
    private var stream: AsyncThrowingStream<Data, Error>.Continuation?

    public override init() {
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

    private func setupFrameStream() {
        let (_events, _stream) = AsyncThrowingStream.makeStream(of: Data.self)
        self.events = _events
        self.stream = _stream
    }

    // MARK: - ScreenCaptureDelegate
    public func screenCaptureProvider(_ provider: ScreenCaptureProvider, didReceiveFrame data: Data) {
        stream?.yield(data)
    }

    public func startCapturing() async throws {
        try await provider.startCapturing()
        setupFrameStream()
    }

    public func stopCapturing() async {
        await provider.stopCapturing()
        stream?.finish()
        stream = nil
    }

    public func requestPermission() async -> Bool {
        return await provider.requestPermission()
    }

    public func prepareForBackground() {
        provider.prepareForBackground()
    }

    public func prepareForForeground() {
        provider.prepareForForeground()
    }
}
