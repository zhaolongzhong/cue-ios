#if os(macOS)
import Foundation
@preconcurrency import ScreenCaptureKit
import CoreGraphics
import os.log
import AppKit
import AVFoundation
import Combine

class MacScreenCaptureProvider: NSObject, ScreenCaptureProvider, SCStreamDelegate, SCStreamOutput {
    func stopCapturing() async {
        logger.debug("Stopping screen capture")

        if let stream = stream {
            do {
                // Stop the capture stream
                try await stream.stopCapture()

                // Remove the stream output
                try stream.removeStreamOutput(self, type: .screen)
                
                // Clean up the stream reference
                self.stream = nil

                logger.debug("Screen capture stopped successfully")
            } catch {
                logger.error("Failed to stop screen capture: \(error.localizedDescription)")
            }
        }
    }

    func requestPermission() async -> Bool {
        //
        return true
    }

    nonisolated func prepareForBackground() {
        //
        print("")
    }

    nonisolated  func prepareForForeground() {
        //
    }

    weak var delegate: ScreenCaptureDelegate?

    private var stream: SCStream?
    private var configuration: SCStreamConfiguration
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "LiveAPI",
                              category: "MacScreenCaptureProvider")

    // Content management
    @Published private(set) var availableDisplays = [SCDisplay]()
    @Published private(set) var availableWindows = [SCWindow]()
    private var availableApps = [SCRunningApplication]()
    private var selectedDisplay: SCDisplay?
    private var isSetup = false
    private var subscriptions = Set<AnyCancellable>()

    override init() {
        self.configuration = SCStreamConfiguration()
        configuration.width = 1920
        configuration.height = 1080
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 30) // 30 FPS
        super.init()
        logger.debug("MacScreenCaptureProvider initialized")
    }

    func startCapturing() async throws {
        logger.debug("Starting screen capture")
        
        // Initialize content monitoring if not already set up
        if !isSetup {
            await monitorAvailableContent()
            isSetup = true
        }

        // Check permission
        guard await requestPermission() else {
            logger.error("Screen capture permission denied")
            throw ScreenCaptureError.permissionDenied
        }

        // Get shareable content and set up filter
        let filter = try await setupContentFilter()

        // Create and start the stream
        stream = SCStream(filter: filter, configuration: configuration, delegate: self)

        if let stream = stream {
            do {
                try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: DispatchQueue.global(qos: .userInitiated))
                try await stream.startCapture()
                logger.debug("Screen capture started successfully")
            } catch {
                logger.error("Failed to start screen capture: \(error.localizedDescription)")
                throw error
            }
        } else {
            logger.error("Stream is nil after setup")
            throw ScreenCaptureError.setupInProgress
        }
    }

    func monitorAvailableContent() async {
        // Start monitoring available content
        await refreshAvailableContent()
        
        // Set up periodic refresh
        // Refresh the lists of capturable content.
        await self.refreshAvailableContent()
        Timer.publish(every: 3, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            guard let self = self else { return }
//            Task {
//                await self.refreshAvailableContent()
//            }
        }
        .store(in: &subscriptions)
    }

    private func refreshAvailableContent() async {
        do {
            let availableContent = try await SCShareableContent.excludingDesktopWindows(false,
                                                                                        onScreenWindowsOnly: true)
            availableDisplays = availableContent.displays

            let windows = filterWindows(availableContent.windows)
            if windows != availableWindows {
                availableWindows = windows
            }
            availableApps = availableContent.applications
            let content = availableDisplays.first
            // Update available displays and windows
            availableApps = []

            // Select first display if none selected
            if selectedDisplay == nil {
                selectedDisplay = availableDisplays.first
            }

        } catch {
            logger.error("Failed to refresh available content: \(error.localizedDescription)")
        }
    }

    private func filterWindows(_ windows: [SCWindow]) -> [SCWindow] {
        windows
            .sorted { $0.owningApplication?.applicationName ?? "" < $1.owningApplication?.applicationName ?? "" }
            .filter { $0.owningApplication != nil && $0.owningApplication?.applicationName != "" }
            .filter { $0.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier }
    }

    private func setupContentFilter() async throws -> SCContentFilter {
        // Get the display to capture
        guard let display = selectedDisplay ?? availableDisplays.first else {
            logger.error("No display available")
            throw ScreenCaptureError.noDisplayFound
        }

        // Filter out the current application
        let excludedApps = availableApps.filter { app in
            Bundle.main.bundleIdentifier == app.bundleIdentifier
        }

        return SCContentFilter(display: display,
                             excludingApplications: excludedApps,
                             exceptingWindows: [])
    }

    // MARK: - SCStreamOutput Implementation
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }

        // Ensure we have a valid image buffer
        guard let imageBuffer = sampleBuffer.imageBuffer else {
            logger.error("No image buffer available")
            return
        }

        // Lock the base address of the pixel buffer
        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)
        }

        // Create a CGImage from the pixel buffer
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            logger.error("Failed to create CGImage")
            return
        }

        // Convert CGImage to NSBitmapImageRep
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)

        // Convert to JPEG data with compression quality of 0.7 (adjust as needed)
        guard let imageData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) else {
            logger.error("Failed to create JPEG data")
            return
        }

        self.delegate?.screenCaptureProvider(self, didReceiveFrame: imageData)
    }

    // MARK: - SCStreamDelegate Implementation
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        logger.error("Stream stopped with error: \(error.localizedDescription)")
//        delegate?.screenCaptureProvider(self, didFailWithError: error)
    }
}
#endif
