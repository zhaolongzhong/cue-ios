import Foundation
import CoreGraphics

enum ScreenCaptureError: Error {
    case noDisplayFound
    case noWindowFound
    case configurationError
    case captureError(String)
    case permissionDenied
    case setupInProgress
}
protocol ScreenCaptureDelegate: AnyObject {
    func screenCaptureProvider(_ provider: ScreenCaptureProvider, didReceiveFrame data: Data)
}

protocol ScreenManagerDelegate: AnyObject {
    func screenManager(_ manager: ScreenManager, didReceiveFrame data: Data)
}

protocol ScreenCaptureProvider: AnyObject {
    var delegate: ScreenCaptureDelegate? { get set }

    func startCapturing() async throws
    func stopCapturing() async
    func requestPermission() async -> Bool
    func prepareForBackground()
    func prepareForForeground()
}
