//
//  AudioManager.swift
//

import Foundation
@preconcurrency import AVFoundation
import os.log
import Combine

// MARK: - AudioManagerDelegate Protocol

protocol AudioManagerDelegate: AnyObject {
    func audioManager(_ manager: AudioManager, didReceiveProcessedAudio data: Data)
    func audioManager(_ manager: AudioManager, didUpdatePlaybackState isPlaying: Bool)
    func checkIsServerTurn() -> Bool
}

// MARK: - AudioManager Class

final class AudioManager: NSObject, @unchecked Sendable {
    // MARK: - Properties
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AudioManager",
                                category: "AudioManager")
    
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var isPlaying: Bool = false
    var turnComplete: Bool = true
    
    private let RECEIVE_SAMPLE_RATE: Double = 24000 // 24kHz
    private let SEND_SAMPLE_RATE: Double = 16000 // 16kHz
    private let CHANNELS: UInt32 = 1
    private var audioFormat: AVAudioFormat?
    
    private var isAudioSetup = false
    
    weak var delegate: AudioManagerDelegate?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        #if os(iOS)
        setupAudioSessionNotifications()
        #endif
        logger.debug("Initializing AudioManager")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Audio Session Notifications
    #if os(iOS)
    private func setupAudioSessionNotifications() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleAudioSessionInterruption),
                                               name: AVAudioSession.interruptionNotification,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleAudioRouteChange),
                                               name: AVAudioSession.routeChangeNotification,
                                               object: nil)
    }
    
    @objc private func handleAudioSessionInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            logger.error("Failed to extract interruption type from notification")
            return
        }
        
        if type == .began {
            logger.debug("Audio session interruption began")
            playerNode.pause()
            isPlaying = false
            delegate?.audioManager(self, didUpdatePlaybackState: false)
        } else if type == .ended {
            logger.debug("Audio session interruption ended")
            do {
                try AVAudioSession.sharedInstance().setActive(true)
                playerNode.play()
                delegate?.audioManager(self, didUpdatePlaybackState: true)
            } catch {
                logger.error("Failed to reactivate audio session after interruption: \(error.localizedDescription)")
            }
        }
    }
    #endif
    
    @objc private func handleAudioRouteChange(notification: Notification) {
        logger.debug("Audio route changed")
        // Implement necessary actions, e.g., reconfigure audio engine
    }
    
    // MARK: - Setup Audio Engine
    
    func setupAudioEngine() async throws {
        guard !isAudioSetup else {
            logger.debug("Audio engine is already set up")
            return
        }
        
        do {
            // Configure AVAudioSession for 16kHz, 16-bit PCM with voice chat mode
            #if os(iOS)
            let session = AVAudioSession.sharedInstance()
            try await MainActor.run {
                try session.setCategory(.playAndRecord,
                                        mode: .voiceChat, // Voice chat mode for echo cancellation
                                        options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP])
                try session.setPreferredSampleRate(SEND_SAMPLE_RATE) // 16kHz
                try session.setActive(true)
                self.logger.debug("Audio session category set to .playAndRecord and activated.")
                self.logger.debug("Preferred sample rate: \(self.SEND_SAMPLE_RATE) Hz")
                self.logger.debug("Actual sample rate: \(session.sampleRate) Hz")
            }
            #endif
            
            let actualSampleRate = RECEIVE_SAMPLE_RATE
            // Define input format as 16kHz, 16-bit PCM little-endian
            let inputFormatSettings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: SEND_SAMPLE_RATE, // 16kHz
                AVNumberOfChannelsKey: CHANNELS,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsFloatKey: false,
            ]
            
            guard let inputAudioFormat = AVAudioFormat(settings: inputFormatSettings) else {
                throw AudioManagerError.audioError(message: "Failed to create input audio format")
            }
            
            logger.debug("Input AudioFormat created with sampleRate: \(inputAudioFormat.sampleRate) Hz, channels: \(inputAudioFormat.channelCount)")
            
            // Initialize format for playback node (Float32 at actualSampleRate)
            audioFormat = AVAudioFormat(standardFormatWithSampleRate: actualSampleRate, channels: CHANNELS)
            
            guard let audioFormat = audioFormat else {
                throw AudioManagerError.audioError(message: "Failed to create audio format")
            }
            
            logger.debug("AudioFormat created with sampleRate: \(audioFormat.sampleRate) Hz, channels: \(audioFormat.channelCount)")
            
            // Attach and connect player node directly to outputNode to prevent playback audio from being captured
            audioEngine.attach(playerNode)
            audioEngine.connect(playerNode, to: audioEngine.outputNode, format: audioFormat)
            logger.debug("Connected playerNode directly to outputNode")
            
            // Install tap on input node with the hardware's actual format
            audioEngine.inputNode.installTap(onBus: 0,
                                             bufferSize: 4096,
                                             format: audioEngine.inputNode.inputFormat(forBus: 0)) { [weak self] buffer, time in
                guard let self = self else { return }
                
                // Perform conversion and send audio data on a background thread
                DispatchQueue.global(qos: .userInitiated).async {
                    self.convertAndSend(buffer: buffer)
                }
            }
            logger.debug("Installed tap on inputNode with hardware's actual format")
            
            // Prepare and start the engine
            audioEngine.prepare()
            try audioEngine.start()
            logger.debug("Audio engine started successfully")
            
            isAudioSetup = true
        } catch {
            logger.error("Error setting up audio engine: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Convert and Send Audio Buffer
    
    private func convertAndSend(buffer: AVAudioPCMBuffer) {
        guard !isPlaying else {
            logger.debug("Skipping audio capture while playing")
            return
        }
        
        if delegate?.checkIsServerTurn() == true {
            logger.debug("Skipping audio capture because it's server turn")
            return
        }
        
        isPlaying = false
        // Define source and destination formats
        let sourceFormat = buffer.format // e.g., 48kHz, Float32
        
        // Define destination format: 16kHz, 16-bit PCM little-endian
        let destinationFormatSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: SEND_SAMPLE_RATE, // 16kHz
            AVNumberOfChannelsKey: CHANNELS,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
        ]
        
        guard let destinationFormat = AVAudioFormat(settings: destinationFormatSettings) else {
            logger.error("Failed to create destination AVAudioFormat")
            return
        }
        
        guard let converter = AVAudioConverter(from: sourceFormat, to: destinationFormat) else {
            logger.error("Failed to create AVAudioConverter")
            return
        }
        
        // Estimate destination buffer frame capacity
        let ratio = destinationFormat.sampleRate / sourceFormat.sampleRate // e.g., 16000 / 48000 = 0.3333
        let destinationFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        
        guard let destinationBuffer = AVAudioPCMBuffer(pcmFormat: destinationFormat, frameCapacity: destinationFrameCapacity) else {
            logger.error("Failed to create destination PCM buffer")
            return
        }
        
        // Initialize the destination buffer
        destinationBuffer.frameLength = destinationFrameCapacity
        
        var error: NSError?
        let status = converter.convert(to: destinationBuffer, error: &error) { inNumPackets, outStatus in
            outStatus.pointee = AVAudioConverterInputStatus.haveData
            return buffer
        }
        
        if status == .error {
            logger.error("Error during conversion: \(error?.localizedDescription ?? "Unknown error")")
            return
        }
        
        // Extract Int16 data from the converted buffer
        guard let int16ChannelData = destinationBuffer.int16ChannelData else {
            logger.error("Failed to access int16ChannelData in destination buffer")
            return
        }
        
        let frameCount = Int(destinationBuffer.frameLength)
        let int16Data = Data(bytes: int16ChannelData[0], count: frameCount * MemoryLayout<Int16>.size)
        
        logger.debug("Converted audio buffer to 16kHz, Int16: \(int16Data.count) bytes")
        
        // Notify delegate with the processed audio data
        Task { @MainActor in
            self.delegate?.audioManager(self, didReceiveProcessedAudio: int16Data)
        }
    }
    
    // MARK: - Play Audio Data
    
    func playAudioData(_ data: Data) async {
        isPlaying = true
        // Log the first few bytes for debugging
        if data.count >= 4 {
            let firstFourBytes = data.prefix(4).map { String(format: "%02X", $0) }.joined(separator: " ")
            logger.debug("First 4 bytes of audio data: \(firstFourBytes)")
        }
        
        // Save audio data to a file for debugging
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("receivedAudio_\(Date().timeIntervalSince1970).pcm")
        do {
            try data.write(to: fileURL)
            logger.debug("Saved received audio data to \(fileURL)")
        } catch {
            logger.error("Failed to save audio data: \(error.localizedDescription)")
        }
        
        guard let audioFormat = audioFormat else {
            logger.error("Audio format not initialized")
            return
        }
        
        // Assume all data is 16-bit PCM at 24kHz
        let frameCount = data.count / 2 // 2 bytes per Int16 sample
        
        // Define source format as 16-bit PCM at 24kHz
        let sourceSampleRate = 24000.0 // 24kHz
        let sourceFormatSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: sourceSampleRate,
            AVNumberOfChannelsKey: CHANNELS,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
        ]
        
        guard let sourceAudioFormat = AVAudioFormat(settings: sourceFormatSettings) else {
            logger.error("Failed to create source AVAudioFormat")
            return
        }
        
        // Create source buffer
        guard let sourceBuffer = AVAudioPCMBuffer(pcmFormat: sourceAudioFormat, frameCapacity: AVAudioFrameCount(frameCount)) else {
            logger.error("Failed to create source PCM buffer")
            return
        }
        
        sourceBuffer.frameLength = AVAudioFrameCount(frameCount)
        
        // Fill source buffer with Int16 data
        data.withUnsafeBytes { ptr in
            guard let samples = ptr.bindMemory(to: Int16.self).baseAddress else {
                logger.error("Failed to bind memory to Int16")
                return
            }
            for i in 0..<frameCount {
                sourceBuffer.int16ChannelData?[0][i] = samples[i]
            }
        }
        logger.debug("Filled source buffer with 16-bit Int data")
        
        // Perform Resampling and conversion to Float32 at RECEIVE_SAMPLE_RATE
        let destinationFormatSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: RECEIVE_SAMPLE_RATE, // 24kHz
            AVNumberOfChannelsKey: CHANNELS,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: true,
        ]
        
        // Adjust destination sample rate to match audio session's actual sample rate
        let destinationSampleRate = audioFormat.sampleRate // e.g., 48000 Hz
        var adjustedDestinationFormatSettings = destinationFormatSettings
        adjustedDestinationFormatSettings[AVSampleRateKey] = destinationSampleRate
        
        guard let destinationFormat = AVAudioFormat(settings: adjustedDestinationFormatSettings) else {
            logger.error("Failed to create destination AVAudioFormat")
            return
        }
        
        guard let converter = AVAudioConverter(from: sourceAudioFormat, to: destinationFormat) else {
            logger.error("Failed to create AVAudioConverter")
            return
        }
        
        // Calculate the required frame capacity for the destination buffer
        let ratio = destinationFormat.sampleRate / sourceSampleRate // e.g., 48000 / 24000 = 2.0
        let destinationFrameCapacity = AVAudioFrameCount(Double(sourceBuffer.frameLength) * ratio)
        
        guard let destinationBuffer = AVAudioPCMBuffer(pcmFormat: destinationFormat, frameCapacity: destinationFrameCapacity) else {
            logger.error("Failed to create destination PCM buffer")
            return
        }
        
        // Initialize the destination buffer
        destinationBuffer.frameLength = destinationFrameCapacity
        
        var error: NSError?
        let status = converter.convert(to: destinationBuffer, error: &error) { inNumPackets, outStatus in
            outStatus.pointee = AVAudioConverterInputStatus.haveData
            return sourceBuffer
        }
        
        if status == .error {
            logger.error("Error during conversion: \(error?.localizedDescription ?? "Unknown error")")
            return
        }
        
        logger.debug("Resampled buffer from \(sourceSampleRate) Hz to \(destinationFormat.sampleRate) Hz")
        
        // Schedule the converted buffer for playback
        playerNode.scheduleBuffer(destinationBuffer) { [weak self] in
            guard let self = self else { return }
            self.logger.debug("Completed playing converted buffer of \(destinationBuffer.frameLength) frames")
            
            // Add delay before resetting isPlaying
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.isPlaying = false
                self.logger.debug("Reset isPlaying state after buffer time")
            }
        }
        
        if !playerNode.isPlaying {
            playerNode.play()
            logger.debug("playerNode started playing")
            await MainActor.run { [weak self] in
                self?.delegate?.audioManager(self!, didUpdatePlaybackState: true)
                self?.logger.debug("isPlaying set to true")
            }
        }
    }
    
    // MARK: - Stop Audio Engine
    
    func stopAudioEngine() {
        isPlaying = false
        playerNode.stop()
        logger.debug("playerNode stopped")
        
        audioEngine.stop()
        logger.debug("audioEngine stopped")
        
        // Reset audio session
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setActive(false)
            logger.debug("Audio session deactivated")
        } catch {
            logger.error("Failed to deactivate audio session: \(error.localizedDescription)")
        }
        #endif
        
        isAudioSetup = false
        Task { @MainActor in
            self.delegate?.audioManager(self, didUpdatePlaybackState: false)
            self.logger.debug("isPlaying set to false and isAudioSetup set to false")
        }
    }
    
    // MARK: - Helper Function for Resampling (Optional)
    
    // This function is retained for potential future use
    func convertBuffer(_ buffer: AVAudioPCMBuffer, from sourceFormat: AVAudioFormat, to destinationFormat: AVAudioFormat) throws -> AVAudioPCMBuffer {
        guard let converter = AVAudioConverter(from: sourceFormat, to: destinationFormat) else {
            throw AudioManagerError.audioError(message: "Failed to create AVAudioConverter")
        }
        
        let ratio = destinationFormat.sampleRate / sourceFormat.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: destinationFormat, frameCapacity: outputFrameCapacity) else {
            throw AudioManagerError.audioError(message: "Failed to create converted PCM buffer")
        }
        
        convertedBuffer.frameLength = 0 // Initialize buffer
        
        var error: NSError?
        let status = converter.convert(to: convertedBuffer, error: &error) { inNumPackets, outStatus in
            outStatus.pointee = AVAudioConverterInputStatus.haveData
            return buffer
        }
        
        if status == .error {
            throw error ?? AudioManagerError.audioError(message: "Unknown conversion error")
        }
        
        // Calculate the number of frames after conversion
        let convertedFrames = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        convertedBuffer.frameLength = convertedFrames
        
        return convertedBuffer
    }
}

// MARK: - AudioManager Errors

enum AudioManagerError: Error {
    case audioError(message: String)
}
