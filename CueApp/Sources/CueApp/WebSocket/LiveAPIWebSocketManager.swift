// LiveAPIWebSocketManager.swift
import Foundation
import AVFoundation
import os.log
import Combine

final class LiveAPIWebSocketManager: NSObject, URLSessionWebSocketDelegate, @unchecked Sendable {
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    
    private var apiKey: String = ""
    private let model = "gemini-2.0-flash-exp"
    private let host = "generativelanguage.googleapis.com"
    
    // Audio configuration
    private let TARGET_SAMPLE_RATE: Double = 48000 // Standard sample rate
    private let CHANNELS: UInt32 = 1
    private var audioFormat: AVAudioFormat?
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "LiveAPI",
                              category: "LiveAPIWebSocketManager")
    
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
    
    override init() {
        super.init()
        setupSession()
        setupAudioSessionNotifications()
        logger.debug("Initializing LiveAPIWebSocketManager")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupSession() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForResource = TimeInterval.infinity
        self.session = URLSession(configuration: configuration,
                                delegate: self,
                                delegateQueue: .main)
        logger.debug("Session setup completed")
    }
    
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
        // Handle audio session interruptions
        logger.debug("Audio session interrupted")
        // Implement necessary actions, e.g., pause audio engine
    }
    
    @objc private func handleAudioRouteChange(notification: Notification) {
        // Handle audio route changes
        logger.debug("Audio route changed")
        // Implement necessary actions, e.g., reconfigure audio engine
    }
    
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
            
            // Send initial setup message
            let setup = LiveAPISetup(setup: .init(model: "models/\(self.model)"))
            Task { [weak self] in
                guard let self = self else { return }
                do {
                    try await self.send(setup)
                    self.logger.debug("Sent initial setup message")
                } catch {
                    self.logger.error("Failed to send setup message: \(error.localizedDescription)")
                }
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
    
    private func setupAudioEngine() async throws {
        do {
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

            // Initialize format to match the main mixer node
            audioFormat = AVAudioFormat(standardFormatWithSampleRate: session.sampleRate,
                                        channels: CHANNELS)

            guard let audioFormat = audioFormat else {
                throw LiveAPIError.audioError(message: "Failed to create audio format")
            }

            logger.debug("AudioFormat created with sampleRate: \(audioFormat.sampleRate), channels: \(audioFormat.channelCount)")

            // Attach and connect player node directly to main mixer
            audioEngine.attach(playerNode)
            audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: audioFormat)
            logger.debug("Connected playerNode to mainMixerNode")
            
            // Install tap on input node if needed
            audioEngine.inputNode.installTap(onBus: 0,
                                             bufferSize: 1024,
                                             format: audioEngine.inputNode.inputFormat(forBus: 0)) { [weak self] buffer, time in
                guard let self = self else { return }
                let audioData = self.processAudioBuffer(buffer)
                
                Task { @MainActor in
                    await self.handleProcessedAudioData(audioData)
                }
            }
            logger.debug("Installed tap on inputNode")
            
            // Prepare and start the engine
            audioEngine.prepare()
            try audioEngine.start()
            logger.debug("Audio engine started successfully")
        } catch {
            logger.error("Error setting up audio engine: \(error.localizedDescription)")
            throw error
        }
    }
    
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
    
    private func send<T: Encodable>(_ message: T) async throws {
        guard let messageData = try? JSONEncoder().encode(message),
              let messageString = String(data: messageData, encoding: .utf8) else {
            throw LiveAPIError.encodingError
        }
        
        try await webSocketTask?.send(.string(messageString))
        logger.debug("Sent message: \(messageString)")
    }
    
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
    
    private func handleTextMessage(_ text: String) async {
        logger.debug("Received text message: \(text)")
        guard let data = text.data(using: .utf8),
              let response = try? JSONDecoder().decode(LiveAPIResponse.self, from: data) else {
            logger.error("Failed to decode response")
            return
        }
        
        if let modelTurn = response.serverContent?.modelTurn,
           let part = modelTurn.parts?.first,
           let inlineData = part.inlineData,
           let audioData = Data(base64Encoded: inlineData.data) {
            await playAudioData(audioData)
        }
    }
    
    private func playAudioData(_ data: Data) async {
        guard let audioFormat = audioFormat else {
            logger.error("Audio format not initialized")
            return
        }
        
        let frameCount = data.count / 2 // 16-bit audio = 2 bytes per frame
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat,
                                          frameCapacity: UInt32(frameCount)) else {
            logger.error("Failed to create PCM buffer")
            return
        }
        
        buffer.frameLength = UInt32(frameCount)
        let channelData = buffer.floatChannelData?[0]
        
        data.withUnsafeBytes { ptr in
            guard let samples = ptr.bindMemory(to: Int16.self).baseAddress else { return }
            for i in 0..<frameCount {
                channelData?[i] = Float(samples[i]) / Float(Int16.max)
            }
        }
        
        playerNode.scheduleBuffer(buffer) { [weak self] in
            print("Completed playing buffer")
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
    
    private func handleBinaryMessage(_ data: Data) async {
        logger.debug("Received binary message of size: \(data.count)")
        
        guard let audioFormat = audioFormat else {
            logger.error("Audio format not initialized")
            return
        }
        
        // Check if this is audio data
        if data.count > 100 {
            logger.debug("Processing binary audio data on audioProcessingQueue")
            audioProcessingQueue.async { [weak self] in
                guard let self = self else { return }
                
                let frameCount = data.count / 2
                self.logger.debug("Frame count: \(frameCount)")
                
                guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat,
                                                  frameCapacity: UInt32(frameCount)) else {
                    self.logger.error("Failed to create PCM buffer")
                    return
                }
                
                buffer.frameLength = UInt32(frameCount)
                self.logger.debug("Created AVAudioPCMBuffer with frameLength: \(buffer.frameLength)")
                
                if let channelData = buffer.floatChannelData {
                    data.withUnsafeBytes { ptr in
                        if let int16Ptr = ptr.bindMemory(to: Int16.self).baseAddress {
                            for i in 0..<frameCount {
                                channelData[0][i] = Float(int16Ptr[i]) / Float(Int16.max)
                            }
                        }
                    }
                    self.logger.debug("Converted Int16 data to Float32 and populated buffer")
                } else {
                    self.logger.error("channelData is nil")
                }
                
                self.playerNode.scheduleBuffer(buffer) { [weak self] in
                    self?.logger.debug("Completed playing buffer of \(frameCount) frames")
                }
                
                if !self.playerNode.isPlaying {
                    self.playerNode.play()
                    self.logger.debug("playerNode started playing")
                    Task { @MainActor in
                        self.isPlaying = true
                        self.logger.debug("isPlaying set to true")
                    }
                }
            }
        } else {
            logger.debug("Received binary data too small to process as audio")
        }
    }
    
    func sendText(_ text: String) async throws {
        logger.debug("Sending text message")
        let content = LiveAPIClientContent(clientContent: .init(
            turnComplete: true,
            turns: [.init(
                role: "user",
                parts: [.init(text: text)]
            )]
        ))
        try await send(content)
    }
    
    func disconnect() {
        webSocketQueue.async { [weak self] in
            guard let self = self else { return }
            self.webSocketTask?.cancel(with: .goingAway, reason: nil)
            self.logger.debug("WebSocket task canceled with goingAway")
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
