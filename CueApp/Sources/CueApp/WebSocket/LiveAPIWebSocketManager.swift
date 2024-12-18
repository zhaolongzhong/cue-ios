// LiveAPIWebSocketManager.swift
import Foundation
import AVFoundation
import os.log
import Combine

// MARK: - LiveAPIWebSocketManager Class

final class LiveAPIWebSocketManager: NSObject, URLSessionWebSocketDelegate, @unchecked Sendable {
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    
    private var apiKey: String = ""
    private let model = "gemini-2.0-flash-exp"
    private let host = "generativelanguage.googleapis.com"
    
    // Audio configuration
    private let TARGET_SAMPLE_RATE: Double = 24000 // 24kHz as per latest requirements
    private let CHANNELS: UInt32 = 1
    private var audioFormat: AVAudioFormat?
    
    let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "LiveAPI",
                                category: "LiveAPIWebSocketManager") // allow extension access
    
    // Audio engine components
    private var audioEngine = AVAudioEngine()
    private var playerNode = AVAudioPlayerNode()
    
    // Queues for audio/video processing
    private var audioInQueue: AsyncQueue<Data>?
    private var outQueue: AsyncQueue<Data>?
    
    @Published private(set) var isPlaying: Bool = false
    private var isAudioSetup = false
    
    // Dedicated background queues for thread safety
    private let webSocketQueue = DispatchQueue(label: "com.yourapp.webSocketQueue")
    private let audioProcessingQueue = DispatchQueue(label: "com.yourapp.audioProcessingQueue")
    private var audioPlayer = AudioStreamPlayer() // another audio player for testing purpose
    
    override init() {
        super.init()
        setupSession()
        setupAudioSessionNotifications()
        logger.debug("Initializing LiveAPIWebSocketManager")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Session Setup
    
    private func setupSession() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForResource = TimeInterval.infinity
        self.session = URLSession(configuration: configuration,
                                  delegate: self,
                                  delegateQueue: .main)
        logger.debug("Session setup completed")
    }
    
    // MARK: - Audio Session Notifications
    
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
        } else if type == .ended {
            logger.debug("Audio session interruption ended")
            do {
                try AVAudioSession.sharedInstance().setActive(true)
                playerNode.play()
                isPlaying = true
            } catch {
                logger.error("Failed to reactivate audio session after interruption: \(error.localizedDescription)")
            }
        }
    }
    
    @objc private func handleAudioRouteChange(notification: Notification) {
        logger.debug("Audio route changed")
        // Implement necessary actions, e.g., reconfigure audio engine
    }
    
    // MARK: - Connect Method
    
    func connect(apiKey: String) async throws {
        self.apiKey = apiKey
        
        // Initialize WebSocket
        let wsURL = "wss://\(host)/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent?key=\(apiKey)"
        guard let url = URL(string: wsURL) else {
            throw LiveAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        webSocketQueue.async { [weak self] in
            guard let self = self else { return }
            self.webSocketTask = self.session?.webSocketTask(with: request)
            self.webSocketTask?.resume()
            self.logger.debug("WebSocket task resumed")
            
            // Send initial setup message with only the model inside "setup"
            let setup = LiveAPISetup(
                setup: SetupDetails(
                    model: "models/\(self.model)"
                )
            )
            
            // Log the setup message being sent
            do {
                let setupData = try JSONEncoder().encode(setup)
                let setupString = String(data: setupData, encoding: .utf8) ?? "Invalid JSON"
                self.logger.debug("Sending setup message: \(setupString)")
                Task {
                    try await self.send(setup)
                    self.logger.debug("Sent initial setup message with model")
                }
            } catch {
                self.logger.error("Failed to encode setup message: \(error.localizedDescription)")
            }
        }
        
        // Setup queues
        audioInQueue = AsyncQueue<Data>(maxSize: 5)
        outQueue = AsyncQueue<Data>(maxSize: 5)
        logger.debug("Audio and output queues initialized")
        
        // Setup audio components if not already set up
        if !isAudioSetup {
            try await setupAudioEngine()
            isAudioSetup = true
            logger.debug("Audio engine setup completed and marked as setup")
        }
        
        // Start receiving messages
        receiveMessage()
    }
    
    // MARK: - Audio Engine Setup

    private func setupAudioEngine() async throws {
        do {
            // Official Guide: https://cloud.google.com/vertex-ai/generative-ai/docs/model-reference/multimodal-live#audio-formats
            // Input audio format: Raw 16 bit PCM audio at 16kHz little-endian
            // Output audio format: Raw 16 bit PCM audio at 24kHz little-endian
            let session = AVAudioSession.sharedInstance()
            try await MainActor.run {
                try session.setCategory(.playAndRecord,
                                        mode: .default,
                                        options: [.defaultToSpeaker, .allowBluetooth])
                try session.setPreferredSampleRate(TARGET_SAMPLE_RATE)
                try session.setActive(true)
                self.logger.debug("Audio session category set and activated.")
                self.logger.debug("Actual sample rate: \(session.sampleRate)")
            }
            
            let actualSampleRate = session.sampleRate
            audioFormat = AVAudioFormat(standardFormatWithSampleRate: actualSampleRate, channels: CHANNELS)
            
            guard let audioFormat = audioFormat else {
                throw LiveAPIError.audioError(message: "Failed to create audio format")
            }
            
            logger.debug("AudioFormat created with sampleRate: \(audioFormat.sampleRate), channels: \(audioFormat.channelCount)")
            
            // Attach and connect player node directly to main mixer
            audioEngine.attach(playerNode)
            audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: audioFormat)
            logger.debug("Connected playerNode to mainMixerNode")
            
            // Install tap on input node if needed (optional for playback)
            // You might not need this unless you're processing input audio
            
            // Prepare and start the engine
            audioEngine.prepare()
            try audioEngine.start()
            logger.debug("Audio engine started successfully")
        } catch {
            logger.error("Error setting up audio engine: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Play Audio Data

    private func playAudioData(_ data: Data) async {
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
        
        let frameCount: Int
        let isFloat32: Bool
        
        if data.count % 4 == 0 { // 32-bit float
            frameCount = data.count / 4
            isFloat32 = true
        } else if data.count % 2 == 0 { // 16-bit Int
            frameCount = data.count / 2
            isFloat32 = false
        } else {
            logger.error("Unsupported audio data size: \(data.count) bytes")
            return
        }
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat,
                                          frameCapacity: UInt32(frameCount)) else {
            logger.error("Failed to create PCM buffer")
            return
        }
        
        buffer.frameLength = UInt32(frameCount)
        guard let channelData = buffer.floatChannelData else {
            logger.error("Failed to get float channel data")
            return
        }
        
        if isFloat32 {
            let floatData = data.withUnsafeBytes { ptr in
                Array(ptr.bindMemory(to: Float.self))
            }
            for i in 0..<frameCount {
                channelData[0][i] = floatData[i]
            }
            logger.debug("Filled buffer with 32-bit float data")
        } else {
            data.withUnsafeBytes { ptr in
                guard let samples = ptr.bindMemory(to: Int16.self).baseAddress else {
                    logger.error("Failed to bind memory to Int16")
                    return
                }
                for i in 0..<frameCount {
                    channelData[0][i] = Float(samples[i]) / Float(Int16.max)
                }
            }
            logger.debug("Filled buffer with 16-bit Int data")
        }
        
        playerNode.scheduleBuffer(buffer) { [weak self] in
            self?.logger.debug("Completed playing buffer of \(frameCount) frames")
        }
        
        if !playerNode.isPlaying {
            playerNode.play()
            logger.debug("playerNode started playing")
            await MainActor.run { [weak self] in
                self?.isPlaying = true
                self?.logger.debug("isPlaying set to true")
            }
        }
    }

    
    // MARK: - Audio Buffer Processing
    
    private nonisolated func processAudioBuffer(_ buffer: AVAudioPCMBuffer) -> Data {
        guard let channelData = buffer.floatChannelData else { return Data() }
        
        let frameCount = Int(buffer.frameLength)
        var int16Data = [Int16](repeating: 0, count: frameCount)
        
        for i in 0..<frameCount {
            let floatSample = channelData[0][i]
            let int16Sample = Int16(max(-32768, min(32767, floatSample * 32767.0)))
            int16Data[i] = int16Sample
        }
        
        return Data(bytes: int16Data, count: frameCount * MemoryLayout<Int16>.size)
    }
    
    // MARK: - Handle Processed Audio Data (Optional)
    
    private func handleProcessedAudioData(_ data: Data) async {
        let base64Data = data.base64EncodedString()
        
        let chunk = LiveAPIRealtimeInput.RealtimeInput.MediaChunk(
            mimeType: "audio/pcm",
            data: base64Data
        )
        let input = LiveAPIRealtimeInput(realtimeInput: .init(mediaChunks: [chunk]))
        
        do {
            try await send(input)
            logger.debug("Sent processed audio data")
        } catch {
            logger.error("Failed to send audio data: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Send Method
    
    func send<T: Encodable>(_ message: T) async throws { // allow extensions access
        guard let messageData = try? JSONEncoder().encode(message),
              let messageString = String(data: messageData, encoding: .utf8) else {
            throw LiveAPIError.encodingError
        }
        
        // Log the message being sent
        logger.debug("Sending message: \(messageString)")
        
        try await webSocketTask?.send(.string(messageString))
    }
    
    // MARK: - Receive Messages
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            Task { [weak self] in
                guard let self = self else { return }
                
                switch result {
                case .success(let message):
                    switch message {
                    case .string(let text):
                        await self.handleTextMessage(text)
                    case .data(let data):
                        await self.handleBinaryMessage(data)
                    @unknown default:
                        self.logger.error("Unknown message type received")
                    }
                    // Continue receiving
                    self.receiveMessage()
                    
                case .failure(let error):
                    self.logger.error("WebSocket receive error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Handle Text Messages
    
    private func handleTextMessage(_ text: String) async {
        logger.debug("Received text message: \(text)")
        guard let data = text.data(using: .utf8),
              let response = try? JSONDecoder().decode(LiveAPIResponse.self, from: data) else {
            logger.error("Failed to decode LiveAPIResponse from text message")
            return
        }
        
        // Process the response as needed
        if let serverContent = response.serverContent,
           let modelTurn = serverContent.modelTurn,
           let part = modelTurn.parts?.first {
            if let inlineData = part.inlineData,
               inlineData.mimeType.starts(with: "audio/pcm") {
                if let decodedAudioData = Data(base64Encoded: inlineData.data) {
                    logger.debug("Received PCM audio data from serverContent")
                    await playAudioData(decodedAudioData)
                } else {
                    logger.error("Failed to decode base64 audio data from serverContent")
                }
            }
            if let text = part.text {
                logger.debug("Received text from server: \(text)")
                // Handle text responses as needed
            }
        }
    }
    
    // MARK: - Handle Binary Messages
    
    private func handleBinaryMessage(_ data: Data) async {
        logger.debug("Received binary message of size: \(data.count) bytes")
        
        // Attempt to convert binary data to string
        guard let messageString = String(data: data, encoding: .utf8) else {
            logger.error("Failed to convert binary data to string")
            return
        }
        
        logger.debug("Binary message as string: \(messageString)")
        
        // Attempt to decode the string as LiveAPIResponse
        guard let jsonData = messageString.data(using: .utf8) else {
            logger.error("Failed to convert message string back to data")
            return
        }
        
        do {
            logger.debug("Attempting to decode LiveAPIResponse")
            let response = try JSONDecoder().decode(LiveAPIResponse.self, from: jsonData)
            
            if let serverContent = response.serverContent,
               let modelTurn = serverContent.modelTurn,
               let part = modelTurn.parts?.first {
                
                if let inlineData = part.inlineData,
                   inlineData.mimeType.starts(with: "audio/pcm") {
                    if let decodedAudioData = Data(base64Encoded: inlineData.data) {
                        logger.debug("Received PCM audio data from serverContent")
                        await playAudioData(decodedAudioData)
                    } else {
                        logger.error("Failed to decode base64 audio data from inlineData")
                    }
                }
                
                if let text = part.text {
                    logger.debug("Received text from serverContent: \(text)")
                    // Handle text responses as needed
                }
            } else if response.setupComplete != nil {
                logger.debug("Received setupComplete message")
                // Handle setup completion if needed
            } else {
                logger.error("Received serverContent without modelTurn or setupComplete")
            }
        } catch {
            logger.error("Failed to decode LiveAPIResponse: \(error.localizedDescription)")
            // Optionally, log raw data in hex for inspection
            let hexString = data.map { String(format: "%02X", $0) }.joined(separator: " ")
            logger.debug("Raw binary data: \(hexString)")
        }
    }

    // MARK: - Disconnect Method
    
    func disconnect() {
        webSocketQueue.async { [weak self] in
            guard let self = self else { return }
            self.webSocketTask?.cancel(with: .goingAway, reason: nil)
            self.logger.debug("WebSocket task canceled with .goingAway")
        }
        
        audioProcessingQueue.async { [weak self] in
            guard let self = self else { return }
            self.playerNode.stop()
            self.logger.debug("playerNode stopped")
            
            self.audioEngine.stop()
            self.logger.debug("audioEngine stopped")
        }
        
        // Reset audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false)
            logger.debug("Audio session deactivated")
        } catch {
            logger.error("Failed to deactivate audio session: \(error.localizedDescription)")
        }
        
        isPlaying = false
        isAudioSetup = false
        logger.debug("isPlaying set to false and isAudioSetup set to false")
    }
}


// MARK: - AsyncQueue Class (Assumed Definition)
@preconcurrency import Foundation

// Make Element conform to Sendable to ensure thread safety
final class AsyncQueue<Element: Sendable> {
    private let maxSize: Int
    private var elements: [Element] = []
    private let lock = NSLock()
    
    init(maxSize: Int) {
        self.maxSize = maxSize
    }
    
    func put(_ element: Element) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            defer { lock.unlock() }
            
            if elements.count < maxSize {
                elements.append(element)
                continuation.resume()
            } else {
                continuation.resume(throwing: QueueError.queueFull)
            }
        }
    }
    
    func get() async throws -> Element {
        return try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            defer { lock.unlock() }
            
            if !elements.isEmpty {
                let element = elements.removeFirst()
                continuation.resume(returning: element)
            } else {
                continuation.resume(throwing: QueueError.queueEmpty)
            }
        }
    }
}

// Custom errors for queue operations
enum QueueError: Error {
    case queueFull
    case queueEmpty
}
