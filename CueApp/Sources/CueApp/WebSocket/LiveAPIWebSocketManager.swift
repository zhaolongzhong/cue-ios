import Foundation
import AVFoundation
import os.log

// MARK: - LiveAPIWebSocketManager

@MainActor
class LiveAPIWebSocketManager: NSObject, URLSessionWebSocketDelegate {
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    
    private var apiKey: String = ""
    private let model = "gemini-2.0-flash-exp"
    private let host = "generativelanguage.googleapis.com"
    
    // Audio configuration
    private let TARGET_SAMPLE_RATE: Double = 24000
    private let CHANNELS: UInt32 = 1
    private var audioFormat: AVAudioFormat?
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "LiveAPI",
                              category: "LiveAPIWebSocketManager")
    
    // Audio engine components
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var converterNode: AVAudioMixerNode?
    private var playerNode: AVAudioPlayerNode?
    
    // Queues for audio/video processing
    private let audioQueue = DispatchQueue(label: "com.cue.audioProcessing", qos: .userInteractive)
    private var audioInQueue: AsyncQueue<Data>?
    private var outQueue: AsyncQueue<Data>?
    
    @Published private(set) var isPlaying: Bool = false
    private var isAudioSetup = false
    
    override init() {
        super.init()
        setupSession()
        logger.debug("Initializing LiveAPIWebSocketManager")
    }
    
    private func setupSession() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForResource = TimeInterval.infinity
        self.session = URLSession(configuration: configuration,
                                delegate: self,
                                delegateQueue: .main)
        logger.debug("Session setup completed")
    }
    
    func connect(apiKey: String) async throws {
        self.apiKey = apiKey
        
        // Initialize websocket first
        let wsURL = "wss://\(host)/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent?key=\(apiKey)"
        guard let url = URL(string: wsURL) else {
            throw LiveAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        webSocketTask = session?.webSocketTask(with: request)
        webSocketTask?.resume()
        
        // Setup queues
        audioInQueue = AsyncQueue<Data>(maxSize: 5)
        outQueue = AsyncQueue<Data>(maxSize: 5)
        
        // Send initial setup message
        let setup = LiveAPISetup(setup: .init(model: "models/\(model)"))
        try await send(setup)
        
        // Setup audio components if not already set up
        if !isAudioSetup {
            try await setupAudioEngine()
            isAudioSetup = true
        }
        
        // Start receiving messages
        receiveMessage()
    }
    
    private func setupAudioEngine() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            audioQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: LiveAPIError.audioError(message: "Self is nil"))
                    return
                }
                
                do {
                    // Create audio components first
                    self.audioEngine = AVAudioEngine()
                    self.playerNode = AVAudioPlayerNode()
                    self.converterNode = AVAudioMixerNode()
                    
                    guard let audioEngine = self.audioEngine,
                          let playerNode = self.playerNode,
                          let converterNode = self.converterNode else {
                        throw LiveAPIError.audioError(message: "Failed to create audio components")
                    }
                    
                    // Configure audio session first
                    let session = AVAudioSession.sharedInstance()
                    try session.setCategory(.playAndRecord,
                                         mode: .default,
                                         options: [.defaultToSpeaker, .allowBluetooth])
                    try session.setPreferredSampleRate(self.TARGET_SAMPLE_RATE)
                    try session.setActive(true)
                    
                    // Get hardware format after session configuration
                    let hwFormat = audioEngine.inputNode.inputFormat(forBus: 0)
                    
                    // Create audio format matching hardware
                    self.audioFormat = AVAudioFormat(standardFormatWithSampleRate: self.TARGET_SAMPLE_RATE,
                                                   channels: self.CHANNELS)
                    
                    guard let audioFormat = self.audioFormat else {
                        throw LiveAPIError.audioError(message: "Failed to create audio format")
                    }
                    
                    // Attach nodes
                    audioEngine.attach(converterNode)
                    audioEngine.attach(playerNode)
                    
                    // Get input node after session is configured
                    self.inputNode = audioEngine.inputNode
                    
                    // Connect nodes
                    audioEngine.connect(audioEngine.inputNode, to: converterNode, format: hwFormat)
                    audioEngine.connect(converterNode, to: audioEngine.mainMixerNode, format: audioFormat)
                    audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: audioFormat)
                    
                    // Configure mixer node
                    converterNode.volume = 0.0 // Mute input monitoring
                    playerNode.volume = 1.0
                    
                    // Install tap on converter
                    converterNode.installTap(onBus: 0,
                                          bufferSize: 1024,
                                          format: audioFormat) { [weak self] buffer, time in
                        guard let self = self else { return }
                        let audioData = self.processAudioBuffer(buffer)
                        
                        Task { @MainActor in
                            await self.handleProcessedAudioData(audioData)
                        }
                    }
                    
                    // Prepare engine
                    audioEngine.prepare()
                    
                    // Start engine
                    try audioEngine.start()
                    
                    self.logger.debug("Audio engine setup completed successfully")
                    continuation.resume()
                    
                } catch {
                    self.logger.error("Failed to setup audio engine: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                }
            }
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
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                switch result {
                case .success(let message):
                    switch message {
                    case .string(let text):
                        await self.handleTextMessage(text)
                    case .data(let data):
                        await self.handleBinaryMessage(data)
                    @unknown default:
                        break
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
        await withCheckedContinuation { continuation in
            audioQueue.async { [weak self] in
                guard let self = self,
                      let audioFormat = self.audioFormat else {
                    continuation.resume()
                    return
                }
                
                let frameCount = data.count / 2 // 16-bit audio = 2 bytes per frame
                guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat,
                                                  frameCapacity: UInt32(frameCount)) else {
                    continuation.resume()
                    return
                }
                
                data.withUnsafeBytes { ptr in
                    guard let samples = ptr.bindMemory(to: Int16.self).baseAddress else { return }
                    let channelData = buffer.floatChannelData?[0]
                    for i in 0..<frameCount {
                        channelData?[i] = Float(samples[i]) / Float(Int16.max)
                    }
                    buffer.frameLength = UInt32(frameCount)
                }
                
                self.playerNode?.scheduleBuffer(buffer) { [weak self] in
                    guard let self = self else { return }
                    Task { @MainActor in
                        self.logger.debug("Completed playing buffer")
                    }
                }
                
                if !(self.playerNode?.isPlaying ?? false) {
                    self.playerNode?.play()
                    Task { @MainActor in
                        self.isPlaying = true
                    }
                }
                
                continuation.resume()
            }
        }
    }
    
    private func handleBinaryMessage(_ data: Data) async {
        logger.debug("Received binary message of size: \(data.count)")
        
        await withCheckedContinuation { continuation in
            audioQueue.async { [weak self] in
                guard let self = self,
                      let audioFormat = self.audioFormat else {
                    self?.logger.error("Audio format not initialized")
                    continuation.resume()
                    return
                }
                
                // Check if this is audio data
                if data.count > 100 {
                    let frameCount = data.count / 2
                    
                    guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat,
                                                      frameCapacity: UInt32(frameCount)) else {
                        self.logger.error("Failed to create PCM buffer")
                        continuation.resume()
                        return
                    }
                    
                    data.withUnsafeBytes { ptr in
                        if let int16Ptr = ptr.bindMemory(to: Int16.self).baseAddress {
                            let channelData = buffer.floatChannelData?[0]
                            for i in 0..<frameCount {
                                channelData?[i] = Float(int16Ptr[i]) / Float(Int16.max)
                            }
                            buffer.frameLength = UInt32(frameCount)
                        }
                    }
                    
                    self.playerNode?.scheduleBuffer(buffer) { [weak self] in
                        guard let self = self else { return }
                        Task { @MainActor in
                            self.logger.debug("Completed playing buffer of \(frameCount) frames")
                        }
                    }
                    
                    if !(self.playerNode?.isPlaying ?? false) {
                        self.playerNode?.play()
                        Task { @MainActor in
                            self.isPlaying = true
                        }
                    }
                }
                
                continuation.resume()
            }
        }
    }
    
    func sendText(_ text: String) async throws {
        logger.debug("send message")
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
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        
        audioQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Cleanup audio
            self.converterNode?.removeTap(onBus: 0)
            self.playerNode?.stop()
            self.audioEngine?.stop()
            
            // Reset audio session
            do {
                try AVAudioSession.sharedInstance().setActive(false)
            } catch {
                self.logger.error("Failed to deactivate audio session: \(error.localizedDescription)")
            }
            
            Task { @MainActor in
                self.isPlaying = false
                self.isAudioSetup = false
            }
        }
    }
}
