import Foundation
import AVFAudio
import os.log

public class OpenAIAudioService: NSObject, OpenAIAudioProtocol {
    // MARK: - Logger
    private let logger = Logger(subsystem: "com.cue.app", category: "OpenAIAudioService")
    
    // MARK: - OpenAIAudioProtocol Properties
    public weak var delegate: OpenAIRealtimeServiceDelegate?
    public private(set) var audioSession: AVAudioSession?
    public private(set) var isRunning: Bool = false
    
    public let sampleRate: Double = 16000 // Standard for most speech recognition
    public let bufferSize: AVAudioFrameCount = 4096
    public let numberOfChannels: Int = 1
    
    // MARK: - Private Properties
    private var audioEngine: AVAudioEngine?
    private var audioBuffer = [Float]()
    
    // MARK: - Initialization
    public override init() {
        super.init()
    }
    
    // MARK: - OpenAIAudioProtocol Methods
    public func start() async throws {
        guard !isRunning else {
            throw OpenAIAudioError.recordingInProgress
        }
        
        // Setup audio session
        try setupAudioSession()
        
        // Setup and start audio engine
        try setupAudioEngine()
        try audioEngine?.start()
        
        isRunning = true
        logger.info("Audio service started successfully")
    }
    
    public func stop() {
        guard isRunning else { return }
        
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        
        try? audioSession?.setActive(false)
        audioSession = nil
        
        isRunning = false
        logger.info("Audio service stopped")
    }
    
    // MARK: - Private Methods
    private func setupAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        
        // Request permission
        var permissionGranted = false
        let semaphore = DispatchSemaphore(value: 0)
        
        session.requestRecordPermission { granted in
            permissionGranted = granted
            semaphore.signal()
        }
        
        _ = semaphore.wait(timeout: .now() + 1.0)
        
        guard permissionGranted else {
            logger.error("Microphone permission denied")
            throw OpenAIAudioError.permissionDenied
        }
        
        do {
            try session.setCategory(.record, mode: .measurement, options: [
                .duckOthers,
                .allowBluetooth,
                .defaultToSpeaker
            ])
            
            try session.setPreferredIOBufferDuration(0.005) // 5ms buffer for low latency
            try session.setPreferredSampleRate(sampleRate)
            try session.setActive(true)
            
            self.audioSession = session
            logger.info("Audio session setup completed successfully")
        } catch {
            logger.error("Failed to setup audio session: \(error.localizedDescription)")
            throw OpenAIAudioError.audioSessionSetupFailed(error)
        }
    }
    
    private func setupAudioEngine() throws {
        let engine = AVAudioEngine()
        let input = engine.inputNode
        
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: AVAudioChannelCount(numberOfChannels),
            interleaved: false
        )
        
        guard let format = format else {
            logger.error("Failed to create audio format")
            throw OpenAIAudioError.invalidAudioFormat
        }
        
        input.installTap(onBus: 0,
                        bufferSize: bufferSize,
                        format: format) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }
        
        try engine.start()
        self.audioEngine = engine
        logger.info("Audio engine setup completed successfully")
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        delegate?.didReceiveAudioBuffer(buffer)
    }
    
    // MARK: - Lifecycle Management
    deinit {
        stop()
        logger.info("Audio service deinitialized")
    }
}