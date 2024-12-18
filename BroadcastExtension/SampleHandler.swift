import ReplayKit
import Foundation
import BroadcastShared

class SampleHandler: RPBroadcastSampleHandler {
    private var frameCount = 0
    private let dataManager = SharedDataManager.shared
    
    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        print("🔴 BroadcastExtension: Started")
        // Try to write test data immediately when broadcast starts
        dataManager.saveFrameData(width: 999, height: 999, frameCount: -999)
    }
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case .video:
            frameCount += 1
            print("🔴 BroadcastExtension: Processing video frame #\(frameCount)")
            
            if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                let width = CVPixelBufferGetWidth(pixelBuffer)
                let height = CVPixelBufferGetHeight(pixelBuffer)
                print("🔴 BroadcastExtension: Saving frame data: \(width)x\(height)")
                
                // Try to read data before writing
                if let existingData = dataManager.getLastFrameData() {
                    print("🔴 BroadcastExtension: Found existing data: \(existingData)")
                }
                
                dataManager.saveFrameData(width: width, height: height, frameCount: frameCount)
                
                // Verify data was written
                if let verifyData = dataManager.getLastFrameData() {
                    print("🔴 BroadcastExtension: Verified saved data: \(verifyData)")
                }
            }
            
        case .audioApp:
            print("🔴 BroadcastExtension: Audio app")
        case .audioMic:
            print("🔴 BroadcastExtension: Audio mic")
        @unknown default:
            print("🔴 BroadcastExtension: Unknown type")
        }
    }
}
