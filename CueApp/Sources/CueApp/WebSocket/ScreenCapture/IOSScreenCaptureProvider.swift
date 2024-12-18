#if os(iOS)
import Foundation
import CoreGraphics
import AVFoundation
import ReplayKit
import os.log
import UIKit

final class IOSScreenCaptureProvider: NSObject, ScreenCaptureProvider {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "LiveAPI",
                              category: "IOSScreenCaptureProvider")
    
    weak var delegate: ScreenManagerDelegate?
    private let recorder = RPScreenRecorder.shared()
    private var displayLink: CADisplayLink?
    private let captureQueue = DispatchQueue(label: "com.screenmanager.capture")
    private var isCaptureSetup = false
    private var isSettingUpCapture = false
    
    // Property for Synchronization
    private var hasResumed = false
    
    override init() {
        super.init()
        logger.debug("IOSScreenCaptureProvider initialized")
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
            await recorder.stopCapture()
            isCaptureSetup = false
            isSettingUpCapture = false
        }
        
        await BackgroundTaskManager.shared.endBackgroundTask(identifier: "screenCapture")
        logger.debug("Screen capture stopped")
    }
    
    func requestPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            recorder.isCameraEnabled = false
            recorder.isMicrophoneEnabled = false
            continuation.resume(returning: recorder.isAvailable)
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
                    
                    if self.isCaptureSetup && error == nil && bufferType == .video {
                        if let frameData = self.compressFrame(buffer) {
                            DispatchQueue.main.async { [weak self] in
                                self?.delegate?.screenManager(self!, didReceiveFrame: frameData)
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
        displayLink?.preferredFramesPerSecond = 30
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
        return uiImage.jpegData(compressionQuality: 0.7)
    }
    
    func prepareForBackground() {
        configureAudioSession()
        
        // Reduce frame rate in background
        Task { @MainActor in
            displayLink?.preferredFramesPerSecond = 15
        }
    }
    
    func prepareForForeground() {
        configureAudioSession()
        
        // Restore normal frame rate
        Task { @MainActor in
            displayLink?.preferredFramesPerSecond = 30
        }
    }
    
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            logger.error("Failed to configure audio session: \(error.localizedDescription)")
        }
    }
}
#endif