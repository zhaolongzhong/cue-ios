#if os(iOS)
import Foundation
import CoreGraphics
import AVFoundation
import ReplayKit
import os.log
import UIKit

final class IOSScreenCaptureProvider: NSObject, ScreenCaptureProvider, @unchecked Sendable {
    weak var delegate: ScreenCaptureDelegate?
    private let recorder = RPScreenRecorder.shared()
    private var displayLink: CADisplayLink?
    private let captureQueue = DispatchQueue(label: "com.screenmanager.capture")
    private var isCaptureSetup = false
    private var isSettingUpCapture = false
    private var isPaused = false

    // Property for Synchronization
    private var hasResumed = false

    override init() {
        super.init()
        logger.debug("ScreenManager initialized")
        setupNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func startCapturing() async throws {
        logger.debug("Starting screen capture")
        guard recorder.isAvailable else {
            logger.error("Screen recording is not available")
            throw ScreenCaptureError.captureError("Screen recording is not available")
        }

        // Start background task before capture
        await BackgroundTaskManager.shared.startBackgroundTask(identifier: "screenCapture") { [weak self] in
            guard let self = self else { return }
            // Ensure stopCapturing is called on captureQueue to serialize access
            self.captureQueue.async {
                Task {
                    await self.stopCapturing()
                }
            }
        }

        // Configure screen recording
        recorder.isMicrophoneEnabled = false

        // Only setup capture once
        if !isCaptureSetup {
            try await setupCapture()
            isCaptureSetup = true
        }

        await startDisplayLink()
    }

    @MainActor
    func stopCapturing() async {
        logger.debug("Stopping screen capture")
        displayLink?.invalidate()
        displayLink = nil

        if isCaptureSetup {
            recorder.stopCapture()
            isCaptureSetup = false
            isSettingUpCapture = false
        }

        BackgroundTaskManager.shared.endBackgroundTask(identifier: "screenCapture")
        logger.debug("Screen capture stopped")
    }

    func requestPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            recorder.isCameraEnabled = false
            recorder.isMicrophoneEnabled = false
            continuation.resume(returning: recorder.isAvailable)
        }
    }

    func prepareForBackground() {
        //
    }

    func prepareForForeground() {
        //
    }

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "LiveAPI",
                              category: "ScreenManager")

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    @objc private func handleAppDidEnterBackground() {
        Task {
            await handleBackgroundTransition()
        }
    }

    @objc private func handleAppWillEnterForeground() {
        Task {
            await handleForegroundTransition()
        }
    }

    private func handleBackgroundTransition() async {
        logger.debug("App entering background")
        isPaused = true

        // Keep the capture session alive but pause frame delivery
        displayLink?.isPaused = true

        // Configure audio session for background
//        configureAudioSession(forBackground: true)
    }

    private func handleForegroundTransition() async {
        logger.debug("App entering foreground")
        isPaused = false

        // Resume frame delivery
        displayLink?.isPaused = false

        // If capture was setup before, ensure it's still running
        if isCaptureSetup {
            do {
                try await refreshCaptureIfNeeded()
            } catch {
                logger.error("Failed to refresh capture: \(error.localizedDescription)")
            }
        }
    }

    private func refreshCaptureIfNeeded() async throws {
        if !recorder.isRecording && isCaptureSetup {
            logger.debug("Refreshing screen capture")
            // Stop existing capture
            await stopCapturing()
            // Start new capture
            try await startCapturing()
        }
    }

    private func setupCapture() async throws {
        guard !isSettingUpCapture else {
            logger.debug("Setup already in progress")
            return
        }

        isSettingUpCapture = true

        try await withCheckedThrowingContinuation { [weak self] (continuation: CheckedContinuation<Void, Error>) in
            guard let self = self else {
                continuation.resume(throwing: ScreenCaptureError.captureError("Self is nil"))
                return
            }

            // Reset hasResumed before starting capture
            self.captureQueue.async {
                self.hasResumed = false
            }

            self.recorder.startCapture(handler: { buffer, bufferType, error in
                self.captureQueue.async { [weak self] in
                    guard let self = self else { return }

                    if !self.isCaptureSetup && !self.hasResumed {
                        self.hasResumed = true
                        self.isCaptureSetup = true
                        self.isSettingUpCapture = false

                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                        return
                    }

                    // Process frames in both foreground and background
                    if self.isCaptureSetup && error == nil && bufferType == .video {
                        // In background mode (isPaused), we'll still process frames but at a lower quality
                        if let frameData = self.compressFrame(buffer) {
                            DispatchQueue.main.async { [weak self] in
                                guard let self = self else { return }
                                self.delegate?.screenCaptureProvider(self, didReceiveFrame: frameData)
                            }
                        }
                    }
                }
            }, completionHandler: { error in
                self.captureQueue.async { [weak self] in
                    guard let self = self else { return }

                    if !self.hasResumed {
                        self.hasResumed = true
                        self.isSettingUpCapture = false
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    }
                }
            })
        }
    }

    @MainActor
    private func startDisplayLink() {
        displayLink?.invalidate()
        displayLink = CADisplayLink(target: self, selector: #selector(self.displayLinkDidFire))
        displayLink?.preferredFramesPerSecond = isPaused ? 5 : 30  // Lower framerate in background
        displayLink?.add(to: .main, forMode: .common)
    }

    @objc private func displayLinkDidFire() {
        // The actual frame capture is handled in the RPScreenRecorder callback
    }

    private func compressFrame(_ sampleBuffer: CMSampleBuffer) -> Data? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }

        // Lock the base address of the pixel buffer
        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)
        }

        // Process the image in a single context
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let context = CIContext()
        let uiImage = UIImage(ciImage: ciImage)
        return uiImage.jpegData(compressionQuality: isPaused ? 0.5 : 0.7)  // Lower quality in background
    }
}

@MainActor
final class BackgroundTaskManager {
    private var backgroundTasks: [String: UIBackgroundTaskIdentifier] = [:]
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    static let shared = BackgroundTaskManager()

    private init() {}

    @MainActor
        func startBackgroundTask(identifier: String, expirationHandler: @escaping @MainActor () -> Void) {
            // End existing task if any
            if let existingTask = backgroundTasks[identifier] {
                UIApplication.shared.endBackgroundTask(existingTask)
                backgroundTasks.removeValue(forKey: identifier)
            }

            let task = UIApplication.shared.beginBackgroundTask { [weak self] in
                Task { @MainActor [weak self] in
                    expirationHandler()
                    self?.endBackgroundTask(identifier: identifier)
                }
            }
            backgroundTasks[identifier] = task
        }

        @MainActor
        func endBackgroundTask(identifier: String) {
            if let task = backgroundTasks[identifier] {
                UIApplication.shared.endBackgroundTask(task)
                backgroundTasks.removeValue(forKey: identifier)
            }
        }
}

#endif
