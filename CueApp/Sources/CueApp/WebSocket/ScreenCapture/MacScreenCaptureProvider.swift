#if os(macOS)
import Foundation
import ScreenCaptureKit
import CoreGraphics
import os.log

final class MacScreenCaptureProvider: NSObject, ScreenCaptureProvider {
    private var stream: SCStream?
    private var configuration: SCStreamConfiguration
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "LiveAPI",
                              category: "MacScreenCaptureProvider")
    
    weak var delegate: ScreenManagerDelegate?
    
    override init() {
        self.configuration = SCStreamConfiguration()
        configuration.width = 1920  // Can be made dynamic based on display
        configuration.height = 1080
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        super.init()
        logger.debug("MacScreenCaptureProvider initialized")
    }
    
    func startCapturing() async throws {
        logger.debug("Starting screen capture")
        let content = try await SCShareableContent.current
        
        guard let display = content.displays.first else {
            logger.error("No display found")
            throw ScreenCaptureError.noDisplayFound
        }
        
        let filter = SCContentFilter(.display(display))
        stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        
        // Add stream output
        try stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: DispatchQueue.global())
        
        try await stream?.startCapture()
    }
    
    func stopCapturing() async {
        logger.debug("Stopping screen capture")
        await stream?.stopCapture()
        stream = nil
    }
    
    func requestPermission() async -> Bool {
        let status = await SCShareableContent.current.authorizationStatus
        return status == .authorized
    }
    
    func prepareForBackground() {
        // No-op on macOS
    }
    
    func prepareForForeground() {
        // No-op on macOS
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
        
        // Create CGImage from CIImage
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        
        // Create NSBitmapImageRep
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        
        // Convert to JPEG data
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.7])
    }
}

extension MacScreenCaptureProvider: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        logger.error("Stream stopped with error: \(error.localizedDescription)")
    }
}

extension MacScreenCaptureProvider: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        
        if let frameData = compressFrame(sampleBuffer) {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.screenManager(self, didReceiveFrame: frameData)
            }
        }
    }
}
#endif