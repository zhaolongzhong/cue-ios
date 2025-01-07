import Foundation
import Combine
@preconcurrency import AVFoundation
import os.log

enum AudioManagerError: LocalizedError, Equatable {
    case engineSetupFailed(String)
    case audioSessionError(String)
    case conversionFailed(String)
    case invalidState(String)
    
    var errorDescription: String? {
        switch self {
        case .engineSetupFailed(let error):
            return "Failed to setup audio engine: \(error)"
        case .audioSessionError(let error):
            return "Audio session error: \(error)"
        case .conversionFailed(let message):
            return "Audio conversion failed: \(message)"
        case .invalidState(let message):
            return "Invalid state: \(message)"
        }
    }
}

enum AudioManagerState: Equatable {
    case idle
    case started
    case paused
    case resumed
    case stopped
    case interrupted // only allow listening
    case playing(id: String?) // listening but skip mic data
    case error(AudioManagerError)
}

protocol AudioManagerDelegate: AnyObject {
    func audioManager(_ manager: AudioManager, didReceiveProcessedAudio data: Data)
    func audioManager(_ manager: AudioManager, didChangeState state: AudioManagerState)
}

public class AudioManager: NSObject, @unchecked Sendable {
    private let logger = Logger(subsystem: "AudioManager",
                              category: "AudioManager")
    
    private struct AudioConstants {
        struct SampleRate {
            static let receive: Double = 24000 // 24kHz, server output
            static let send: Double = 16000 // 16kHz, server input
        }
        static let channels: UInt32 = 1
        static let bufferSize: AVAudioFrameCount = 4096
    }
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let audioFormat: AVAudioFormat
    

    private var isAudioEngineSetup = false
    private var isListening = false
    private var playbackQueue: [(data: Data, id: String)] = []
    private var currentItemID: String?
    
    private var state: AudioManagerState = .idle {
        didSet {
            delegate?.audioManager(self, didChangeState: state)
        }
    }
    
    weak var delegate: AudioManagerDelegate?
    
    override init() {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: AudioConstants.SampleRate.receive, channels: AudioConstants.channels) else {
            fatalError("Failed to create AVAudioFormat")
        }
        self.audioFormat = format
        super.init()
    }
    
    @MainActor
    func cleanup() async {
        stopAudioEngine()
    }
    
    // MARK: - State Management
        
    @MainActor
    private func updateState(to newState: AudioManagerState) {
        guard state != newState else { return }
        state = newState
    }
    
    deinit {
        delegate = nil
    }
    
    // MARK: - Setup Audio Engine
    
    @MainActor func setupAudioEngine() async throws {
        guard !isAudioEngineSetup else { return }
        
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord,
                             mode: .voiceChat,
                             options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)
        #endif
        
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: audioFormat)
        
        // Access inputNode to ensure it's initialized
        let _ = audioEngine.inputNode
        
        do {
            // Prepare and start the engine
            audioEngine.prepare()
            try audioEngine.start()
            isAudioEngineSetup = true
            logger.debug("Audio engine prepared and started successfully")
            // Add a small delay before installing the tap
            try await Task.sleep(nanoseconds: 100_000_000)
            startRecording()
        } catch {
            stopAudioEngine()
            logger.error("Error setting up audio engine: \(error.localizedDescription)")
            throw error
        }
    }
    
    @MainActor func startRecording() {
        guard !isListening else { return }
        logger.debug("Start recording")
        
        // Detach audio processing off the main thread
        Task.detached {
            self.audioEngine.inputNode.installTap(onBus: 0, bufferSize: AudioConstants.bufferSize, format: self.audioEngine.inputNode.outputFormat(forBus: 0)) { [weak self] buffer, time in
                guard let self = self else { return }
                self.processAudioBufferFromUser(buffer: buffer)
            }
        }
        isListening = true
        logger.debug("Installed tap on inputNode")
        updateState(to: .started)
    }
    
    @MainActor func pauseRecording() {
        if isListening {
            audioEngine.inputNode.removeTap(onBus: 0)
            isListening = false
            updateState(to: .paused)
        }
    }
    
    @MainActor func resumeRecording() {
        startRecording()
        updateState(to: .resumed)
    }
    
    // MARK: - Stop Audio Engine
    
    @MainActor func stopAudioEngine() {
        guard isAudioEngineSetup else {
            logger.error("try stopAudioEngine when audioEngine is not setup")
            return
        }
        
        logger.debug("Stop audio engine started")
        
        // First update state to prevent new audio from being queued
        updateState(to: .stopped)
        isAudioEngineSetup = false
        
        // Clear queue immediately
        playbackQueue.removeAll()
        
        Task.detached { [weak self] in
            guard let self = self else { return }
            
            // First stop audio engine to prevent new audio processing
            self.logger.debug("Stopping audio engine...")
            self.audioEngine.stop()
            self.logger.debug("Audio engine stopped")
            
            // Give a small pause to let buffers clear
            try? await Task.sleep(nanoseconds: 50_000_000)  // 50ms
            
            if self.playerNode.isPlaying {
                self.logger.debug("Stopping player node...")
                // Reset the node before stopping
                self.playerNode.reset()  // This clears any pending buffers
                self.playerNode.stop()
                try? await Task.sleep(nanoseconds: 10_000_000)  // 10ms
                // Double check if it's really stopped
                if self.playerNode.isPlaying {
                    self.logger.warning("Player node still playing after stop attempt")
                    // Force stop again
                    self.playerNode.reset()
                    self.playerNode.stop()
                }
                self.logger.debug("Player node stopped")
            }
            
            // Remove tap after stopping everything
            if self.isListening {
                self.audioEngine.inputNode.removeTap(onBus: 0)
                self.logger.debug("Removed input tap")
            }
            
            // Detach nodes
            if self.audioEngine.attachedNodes.contains(self.playerNode) {
                self.audioEngine.detach(self.playerNode)
                self.logger.debug("Detached player node")
            }
            
            // Handle audio session cleanup on main thread
            await MainActor.run {
                #if os(iOS)
                do {
                    try AVAudioSession.sharedInstance().setActive(false,
                        options: .notifyOthersOnDeactivation)
                    self.logger.debug("Audio session deactivated")
                } catch {
                    self.logger.error("Failed to deactivate audio session: \(error)")
                }
                #endif
                
                self.isListening = false
            }
        }
    }
    
    // MARK: - Convert and Send Audio Buffer
    
    private func processAudioBufferFromUser(buffer: AVAudioPCMBuffer) {
        guard !playerNode.isPlaying else {
            return
        }
        
        do {
            let destinationConfig = AudioConversionConfig.pcm16(sampleRate: AudioConstants.SampleRate.send)
            let convertedBuffer = try convertBuffer(buffer, toConfig: destinationConfig)
            let int16Data = try convertBufferToInt16Data(convertedBuffer)
            self.delegate?.audioManager(self, didReceiveProcessedAudio: int16Data)
        } catch {
            logger.error("Audio conversion failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Playback Methods
    /// Calculates the current playback position in milliseconds
    /// - Returns: The current audio position in milliseconds, or nil if timing information is unavailable
    func getAudioEndMsForInterrupt() -> Int? {
        guard let nodeTime = playerNode.lastRenderTime,
              let playerTime = playerNode.playerTime(forNodeTime: nodeTime) else {
            return nil
        }
        
        // Use floating-point arithmetic for better precision
        let sampleTimeDouble = Double(playerTime.sampleTime)
        let sampleRateDouble = Double(playerTime.sampleRate)
        
        // Guard against division by zero
        guard sampleRateDouble > 0 else {
            return nil
        }
        
        // Calculate time in milliseconds with rounding
        let audioTimeInMilliseconds = Int(round((sampleTimeDouble / sampleRateDouble) * 1000))
        
        return audioTimeInMilliseconds
    }
    
    func interrupt() {
        playbackQueue.removeAll()
        if playerNode.isPlaying {
            playerNode.stop()
        }
    }
    
    func playAudioData(_ data: Data, id: String) {
        playbackQueue.append((data: data, id: id))
        if !playerNode.isPlaying {
            processNextInQueue()
        }
    }
    
    private func processNextInQueue() {
        guard !playbackQueue.isEmpty else {
            playerNode.pause()
            return
        }
        
        let (data, id) = playbackQueue.removeFirst()
        currentItemID = id
        
        if let playerAudioBuffer = preparePlayerAudioBuffer(from: data) {
            playerNode.scheduleBuffer(playerAudioBuffer) { [weak self] in
                guard let self = self else { return }
                    self.currentItemID = nil
                    self.processNextInQueue()
            }
            
            if !playerNode.isPlaying {
                playerNode.play()
                logger.debug("playerNode started playing Event ID: \(id)")
            }
        } else {
            logger.error("Failed to prepare buffer for Event ID: \(id)")
            currentItemID = nil
            processNextInQueue()
        }
    }
    
    private func preparePlayerAudioBuffer(from data: Data) -> AVAudioPCMBuffer? {
        do {
            // Convert incoming PCM16 data to buffer
            let sourceConfig = AudioConversionConfig.pcm16(sampleRate: AudioConstants.SampleRate.receive)
            let sourceBuffer = try convertPCMDataToBuffer(data, config: sourceConfig)
            
            // Convert to float format for playback
            let destinationConfig = AudioConversionConfig.float32(sampleRate: audioFormat.sampleRate)
            return try convertBuffer(sourceBuffer, toConfig: destinationConfig)
        } catch {
            logger.error("Failed to prepare buffer: \(error.localizedDescription)")
            return nil
        }
    }
}
