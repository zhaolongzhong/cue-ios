import ReplayKit
import Foundation
import BroadcastShared
import os.log
import CoreImage
import VideoToolbox

@_cdecl("CreateSampleHandler")
public func CreateSampleHandler() -> RPBroadcastSampleHandler {
    os_log("🔴 CreateSampleHandler called", type: .fault)
    return SampleHandler()
}

class SampleHandler: RPBroadcastSampleHandler {
    private var frameCount = 0
    private let dataManager = SharedDataManager.shared
    private let logger = OSLog(subsystem: "ai.nextlabs.app.BroadcastExtension", category: "Broadcast")
    private let ciContext = CIContext()
    
    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        os_log("🔴 BroadcastExtension: Started", log: logger, type: .info)
//        dataManager.saveFrameData(width: 999, height: 999, frameCount: -999)
    }
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case .video:
            frameCount += 1
            
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                return
            }
            
            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)
            
            // Convert frame to JPEG data
            if let frameData = createJPEGData(from: pixelBuffer) {
                dataManager.saveFrameData(width: width, height: height, frameCount: frameCount, frameData: frameData)
            }
        case .audioApp:
            os_log("🔴 BroadcastExtension: Audio app", log: logger, type: .info)
        case .audioMic:
            os_log("🔴 BroadcastExtension: Audio mic", log: logger, type: .info)
        @unknown default:
            os_log("🔴 BroadcastExtension: Unknown type", log: logger, type: .error)
        }
    }
    
    override func broadcastFinished() {
        os_log("🔴 BroadcastExtension: Finished", log: logger, type: .info)
    }
    
    override func finishBroadcastWithError(_ error: Error) {
        os_log("🔴 BroadcastExtension: Error - %{public}@", log: logger, type: .error, error.localizedDescription)
        super.finishBroadcastWithError(error)
    }
    
    private func createJPEGData(from pixelBuffer: CVPixelBuffer) -> Data? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        
        return autoreleasepool { () -> Data? in
            let imageData = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(imageData as CFMutableData, "public.jpeg" as CFString, 1, nil) else {
                return nil
            }
            
            let options: [CFString: Any] = [
                kCGImageDestinationLossyCompressionQuality: 0.7 // Adjust quality (0.0 to 1.0)
            ]
            
            CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
            
            if CGImageDestinationFinalize(destination) {
                return imageData as Data
            }
            
            return nil
        }
    }
}
