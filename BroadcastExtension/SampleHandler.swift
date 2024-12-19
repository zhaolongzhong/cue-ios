import ReplayKit
import Foundation
import BroadcastShared
import os.log

@_cdecl("CreateSampleHandler")
public func CreateSampleHandler() -> RPBroadcastSampleHandler {
    os_log("🔴 CreateSampleHandler called", type: .fault)
    return SampleHandler()
}

class SampleHandler: RPBroadcastSampleHandler {
    private var frameCount = 0
    private let dataManager = SharedDataManager.shared
    private let logger = OSLog(subsystem: "ai.nextlabs.app.BroadcastExtension", category: "Broadcast")
    
    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        os_log("🔴 BroadcastExtension: Started", log: logger, type: .info)
        dataManager.saveFrameData(width: 999, height: 999, frameCount: -999)
    }
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case .video:
            frameCount += 1
            os_log("🔴 BroadcastExtension: Frame #%d", log: logger, type: .info, frameCount)
            
            if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                let width = CVPixelBufferGetWidth(pixelBuffer)
                let height = CVPixelBufferGetHeight(pixelBuffer)
                os_log("🔴 BroadcastExtension: Size %dx%d", log: logger, type: .info, width, height)
                dataManager.saveFrameData(width: width, height: height, frameCount: frameCount)
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
}
