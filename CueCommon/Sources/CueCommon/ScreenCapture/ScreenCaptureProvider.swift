import Foundation
import CoreGraphics

public enum ScreenCaptureError: Error {
    case noDisplayFound
    case noWindowFound
    case configurationError
    case captureError(String)
    case permissionDenied
    case setupInProgress
}

public protocol ScreenCaptureDelegate: AnyObject {
    func screenCaptureProvider(_ provider: ScreenCaptureProvider, didReceiveFrame data: Data)
}

public protocol ScreenCaptureProvider: AnyObject {
    var delegate: ScreenCaptureDelegate? { get set }

    func startCapturing() async throws
    func stopCapturing() async
    func requestPermission() async -> Bool
    func prepareForBackground()
    func prepareForForeground()
}
