import Foundation
import AVFAudio
import Combine

public protocol OpenAIAudioProtocol {
    // Core functionality
    func start() async throws
    func stop()
    
    // Configuration
    var audioSession: AVAudioSession? { get }
    var isRunning: Bool { get }
    
    // Event handling
    var delegate: OpenAIRealtimeServiceDelegate? { get set }
    
    // Audio properties
    var sampleRate: Double { get }
    var bufferSize: AVAudioFrameCount { get }
    var numberOfChannels: Int { get }
}

public protocol OpenAIRealtimeServiceDelegate: AnyObject {
    func didEncounterError(_ error: Error)
    func didReceiveAudioBuffer(_ buffer: AVAudioPCMBuffer)
}