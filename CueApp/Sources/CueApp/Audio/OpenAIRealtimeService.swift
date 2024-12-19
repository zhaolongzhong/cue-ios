import Foundation
import AVFoundation
import WebSockets

/// Service for handling realtime audio transcription using OpenAI's Whisper API
@available(iOS 13.0, macOS 10.15, *)
final class OpenAIRealtimeService: NSObject {
    // MARK: - Constants
    private enum Constants {
        static let audioBufferSize = 4096
        static let minAudioLevel: Float = 0.01
        static let maxRetryAttempts = 3
        static let retryDelay: TimeInterval = 2.0
    }
    private let config: OpenAIRealtimeConfig
    private weak var delegate: OpenAIRealtimeDelegate?
    
    private var audioEngine: AVAudioEngine?
    private var audioSession: AVAudioSession?
    private var webSocket: WebSocket?
    
    private var audioBuffer = [Float]()
    private var isRecording = false
    private var lastSpeechTime: TimeInterval = 0
    private var transcriptionStartTime: TimeInterval?
    
    private var state: ConnectionState = .disconnected {
        didSet {
            delegate?.connectionStateDidChange(state)
        }
    }
    
    /// Creates a new OpenAI Realtime service instance
    /// - Parameters:
    ///   - config: The service configuration
    ///   - delegate: The delegate to receive updates
    init(config: OpenAIRealtimeConfig, delegate: OpenAIRealtimeDelegate) {
        self.config = config
        self.delegate = delegate
        super.init()
    }
    
    /// Starts the transcription service
    func start() async throws {
        guard !isRecording else { return }
        
        // Set up audio session
        try setupAudioSession()
        
        // Set up WebSocket connection
        try await connectWebSocket()
        
        // Start audio engine
        try startAudioEngine()
        
        isRecording = true
        state = .connected
    }
    
    /// Stops the transcription service
    func stop() {
        guard isRecording else { return }
        
        stopAudioEngine()
        webSocket?.close()
        webSocket = nil
        
        audioBuffer.removeAll()
        isRecording = false
        state = .disconnected
        transcriptionStartTime = nil
    }
    
    /// Processes speech detection and sends audio data
    /// - Parameter buffer: The audio buffer to process
    private func processSpeechDetection(_ buffer: AVAudioPCMBuffer) {
        // Convert buffer to array of samples
        let samples = Array(UnsafeBufferPointer(start: buffer.floatChannelData?[0],
                                              count: Int(buffer.frameLength)))
        
        // Calculate audio level
        let level = calculateAudioLevel(samples)
        delegate?.audioLevelDidChange(level)
        
        // Add samples to buffer
        audioBuffer.append(contentsOf: samples)
        
        // Check if we have enough audio for speech detection
        if audioBuffer.count >= config.sampleRate / 10 { // 100ms chunks
            let isSpeech = detectSpeech(in: audioBuffer)
            processAudioChunk(isSpeech: isSpeech)
        }
    }
    
    /// Detects speech in audio data using energy-based VAD
    private func detectSpeech(in samples: [Float]) -> Bool {
        let energy = samples.reduce(0) { $0 + abs($1) }
        let avgEnergy = energy / Float(samples.count)
        
        // Simple energy threshold for speech detection
        // TODO: Implement more sophisticated VAD
        return avgEnergy > 0.01
    }
    
    /// Process audio chunk based on speech detection
    private func processAudioChunk(isSpeech: Bool) {
        let now = Date().timeIntervalSince1970
        
        if isSpeech {
            if lastSpeechTime == 0 {
                delegate?.speechDetected()
                state = .processing
                transcriptionStartTime = now
            }
            lastSpeechTime = now
            
            // Send audio if we have accumulated enough
            if audioBuffer.count >= config.sampleRate {
                sendAudioData()
            }
        } else {
            // Check for end of speech
            let silenceDuration = now - lastSpeechTime
            if lastSpeechTime > 0 && silenceDuration * 1000 >= Double(config.silenceThresholdMs) {
                endSpeechSegment()
            }
        }
        
        // Check max duration
        if let startTime = transcriptionStartTime,
           now - startTime >= Double(config.maxDurationSec) {
            endSpeechSegment()
        }
    }
    
    /// Sends accumulated audio data to server
    private func sendAudioData() {
        guard let webSocket = webSocket else { return }
        
        // Convert float samples to 16-bit PCM
        var pcmData = Data(capacity: audioBuffer.count * 2)
        audioBuffer.forEach { sample in
            let intSample = Int16(sample * 32767)
            pcmData.append(contentsOf: [UInt8](withUnsafeBytes(of: intSample) { Data($0) }))
        }
        
        // Send audio data
        Task {
            do {
                try await webSocket.send(pcmData)
            } catch {
                delegate?.didEncounterError(OpenAIRealtimeError.networkError(error))
            }
        }
        
        // Clear buffer after sending
        audioBuffer.removeAll()
    }
    
    /// Ends the current speech segment
    private func endSpeechSegment() {
        sendAudioData() // Send any remaining audio
        delegate?.speechEnded()
        state = .connected
        lastSpeechTime = 0
        transcriptionStartTime = nil
    }
    
    /// Calculates RMS audio level
    private func calculateAudioLevel(_ samples: [Float]) -> Float {
        let squares = samples.map { $0 * $0 }
        let sum = squares.reduce(0, +)
        let rms = sqrt(sum / Float(samples.count))
        return min(max(rms, 0), 1)
    }
}

// MARK: - Audio Setup
extension OpenAIRealtimeService {
    private func setupAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        
        // Request permission first
        var permissionGranted = false
        session.requestRecordPermission { granted in
            permissionGranted = granted
        }
        
        // Wait for permission response
        let start = Date()
        while Date().timeIntervalSince(start) < 1.0 && !permissionGranted {
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        guard permissionGranted else {
            throw OpenAIRealtimeError.permissionDenied
        }
        
        try session.setCategory(.record, mode: .measurement, options: [
            .duckOthers,      // Lower other audio
            .allowBluetooth,  // Allow Bluetooth microphones
            .defaultToSpeaker // Use speaker for playback
        ])
        
        // Configure session for optimal audio quality
        try session.setPreferredIOBufferDuration(0.005) // 5ms buffer for low latency
        try session.setPreferredSampleRate(Double(config.sampleRate))
        try session.setActive(true)
        
        // Add lifecycle observers
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        
        self.audioSession = session
    }
    
    private func startAudioEngine() throws {
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        
        input.installTap(onBus: 0,
                        bufferSize: AVAudioFrameCount(config.sampleRate / 10),
                        format: format) { [weak self] buffer, time in
            self?.processSpeechDetection(buffer)
        }
        
        try engine.start()
        self.audioEngine = engine
    }
    
    private func stopAudioEngine() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        
        deactivateAudioSession()
    }
    
    private func deactivateAudioSession() {
        try? audioSession?.setActive(false)
        audioSession = nil
        
        // Remove observers
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: nil)
    }
    
    @objc private func handleAudioSessionInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            stop() // Full stop on interruption
        case .ended:
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                // Attempt to restart
                Task {
                    do {
                        try await start()
                    } catch {
                        delegate?.didEncounterError(error)
                    }
                }
            }
        @unknown default:
            break
        }
    }
    
    @objc private func handleAudioRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        // Handle route changes that require restarting
        switch reason {
        case .newDeviceAvailable, .oldDeviceUnavailable:
            // Stop current session
            stop()
            
            // Attempt to restart with new audio route
            Task {
                do {
                    try await start()
                } catch {
                    delegate?.didEncounterError(error)
                }
            }
        default:
            break
        }
    }
}

// MARK: - WebSocket Setup
extension OpenAIRealtimeService {
    private func connectWebSocket() async throws {
        let url = URL(string: "wss://api.openai.com/v1/audio/transcribe")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("audio/raw", forHTTPHeaderField: "Content-Type")
        
        let ws = try await WebSocket(request: request)
        
        ws.onText { [weak self] ws, text in
            self?.handleTranscriptionResponse(text)
        }
        
        ws.onError { [weak self] ws, error in
            self?.delegate?.didEncounterError(OpenAIRealtimeError.networkError(error))
        }
        
        self.webSocket = ws
    }
    
    private func handleTranscriptionResponse(_ text: String) {
        guard let data = text.data(using: .utf8),
              let response = try? JSONDecoder().decode(TranscriptionResponse.self, from: data) else {
            delegate?.didEncounterError(OpenAIRealtimeError.serverError("Invalid response format"))
            return
        }
        
        let result = TranscriptionResult(
            text: response.text,
            isInterim: response.isInterim ?? true,
            confidence: response.confidence,
            timestamp: response.timestamp
        )
        
        delegate?.didReceiveTranscription(result)
    }
}

// MARK: - Response Types
private struct TranscriptionResponse: Decodable {
    let text: String
    let isInterim: Bool?
    let confidence: Float?
    let timestamp: TimeInterval?
}