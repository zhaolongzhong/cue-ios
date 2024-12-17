import Foundation
import AVFoundation
import os.log

@MainActor
class LiveAPIWebSocketManager: NSObject, URLSessionWebSocketDelegate {
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    
    private var apiKey: String = ""
    private let model = "gemini-2.0-flash-exp"
    private let host = "generativelanguage.googleapis.com"
    
    // Audio configuration
    private let TARGET_SAMPLE_RATE: Double = 16000  // Required for the API
    private let CHANNELS: UInt32 = 1
    private var audioConverter: AVAudioConverter?
    
    // Audio engine components
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var converterNode: AVAudioMixerNode?
    private var playerNode: AVAudioPlayerNode?
    
    // Queues for audio/video processing
    private let processingQueue = DispatchQueue(label: "audioProcessing", qos: .userInteractive)
    private var audioInQueue: AsyncQueue<Data>?
    private var outQueue: AsyncQueue<Data>?
    
    override init() {
        super.init()
        setupSession()
    }
    
    private func setupSession() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForResource = TimeInterval.infinity
        self.session = URLSession(configuration: configuration,
                                delegate: self,
                                delegateQueue: nil)
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
        
        // Start receiving messages
        receiveMessage()
    }
    
    func startAudioCapture() async throws {
        guard isAudioPermissionGranted() else {
            throw LiveAPIError.audioError(message: "Microphone permission not granted")
        }
        
        // Initialize audio components
        do {
            try await setupAudioEngine()
        } catch {
            os_log(.error, "Failed to setup audio engine: %{public}@", error.localizedDescription)
            throw error
        }
    }
    
    private func isAudioPermissionGranted() -> Bool {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            // We should request permission before reaching here
            return false
        @unknown default:
            return false
        }
    }
    
    private func setupAudioEngine() async throws {
        // Create components first
        audioEngine = AVAudioEngine()
        inputNode = audioEngine?.inputNode
        converterNode = AVAudioMixerNode()
        playerNode = AVAudioPlayerNode()
        
        guard let audioEngine = audioEngine,
              let inputNode = inputNode,
              let converterNode = converterNode,
              let playerNode = playerNode else {
            throw LiveAPIError.audioError(message: "Failed to create audio components")
        }
        
        // Get a local copy of engine for background tasks
        let engine = audioEngine
        
        // Configure audio session on a background thread
        try await Task.detached {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, 
                                     mode: .default,
                                     options: [.defaultToSpeaker, .allowBluetooth])
            try AVAudioSession.sharedInstance().setActive(true)
            os_log(.debug, "Audio session configured successfully")
        }.value
        
        // Setup audio processing chain
        audioEngine.attach(converterNode)
        audioEngine.attach(playerNode)
        
        // Get hardware format
        let hwFormat = inputNode.inputFormat(forBus: 0)
        let targetFormat = AVAudioFormat(standardFormatWithSampleRate: TARGET_SAMPLE_RATE,
                                       channels: CHANNELS)!
        
        // Connect nodes
        audioEngine.attach(converterNode)
        audioEngine.attach(playerNode)
        audioEngine.connect(inputNode, to: converterNode, format: hwFormat)
        audioEngine.connect(converterNode, to: audioEngine.mainMixerNode, format: targetFormat)
        
        // Install tap with data handler
        converterNode.installTap(onBus: 0,
                               bufferSize: 1024,
                               format: targetFormat) { [weak self] buffer, time in
            guard let self = self else { return }
            let audioData = self.processAudioBuffer(buffer)
            
            // Send processed data to main actor
            Task { @MainActor in
                await self.handleProcessedAudioData(audioData)
            }
        }
        
        // Prepare engine before starting
        audioEngine.prepare()
        
        // Start the engine in a way that's safe for actor isolation
        do {
            // Create an isolated copy of the engine reference
            let isolatedEngine = engine
            try await withCheckedThrowingContinuation { continuation in
                do {
                    try isolatedEngine.start()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            os_log(.debug, "Audio engine setup completed")
        } catch {
            os_log(.error, "Failed to start audio engine: %{public}@", error.localizedDescription)
            throw error
        }
    }
    
    // Non-isolated method for processing audio buffer
    private nonisolated func processAudioBuffer(_ buffer: AVAudioPCMBuffer) -> Data {
        guard let channelData = buffer.floatChannelData else { return Data() }
        
        let frameCount = Int(buffer.frameLength)
        var int16Data = [Int16](repeating: 0, count: frameCount)
        
        // Convert float to int16
        for i in 0..<frameCount {
            let floatSample = channelData[0][i]
            let int16Sample = Int16(max(-32768, min(32767, floatSample * 32767.0)))
            int16Data[i] = int16Sample
        }
        
        return Data(bytes: int16Data, count: frameCount * MemoryLayout<Int16>.size)
    }
    
    // Main actor method for handling processed audio data
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
            os_log(.error, "Failed to send audio data: %{public}@", error.localizedDescription)
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
                    os_log(.error, "WebSocket receive error: %{public}@", error.localizedDescription)
                }
            }
        }
    }
    
    private func handleTextMessage(_ text: String) async {
        guard let data = text.data(using: .utf8),
              let response = try? JSONDecoder().decode(LiveAPIResponse.self, from: data) else {
            os_log(.error, "Failed to decode response")
            return
        }
        
        if let modelTurn = response.serverContent?.modelTurn,
           let part = modelTurn.parts?.first,
           let inlineData = part.inlineData,
           let audioData = Data(base64Encoded: inlineData.data) {
            await playAudioData(audioData)
        }
    }
    
    private func handleBinaryMessage(_ data: Data) async {
        os_log(.debug, "Received binary message of size: %d", data.count)
    }
    
    private func playAudioData(_ data: Data) async {
        // Convert base64 PCM data to audio buffer and play through engine
        guard let format = AVAudioFormat(standardFormatWithSampleRate: TARGET_SAMPLE_RATE,
                                       channels: CHANNELS),
              let buffer = try? AVAudioPCMBuffer(pcmFormat: format,
                                               frameCapacity: UInt32(data.count / 2)) else {
            os_log(.error, "Failed to create audio buffer for playback")
            return
        }
        
        data.withUnsafeBytes { ptr in
            guard let samples = ptr.bindMemory(to: Int16.self).baseAddress else {
                return
            }
            for i in 0..<Int(buffer.frameCapacity) {
                let floatSample = Float(samples[i]) / 32767.0
                buffer.floatChannelData?[0][i] = floatSample
            }
            buffer.frameLength = buffer.frameCapacity
        }
        
        playerNode?.scheduleBuffer(buffer, completionHandler: nil)
        playerNode?.play()
    }
    
    func sendText(_ text: String) async throws {
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
        
        // Cleanup audio
        converterNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        
        // Reset audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            os_log(.error, "Failed to deactivate audio session: %{public}@", error.localizedDescription)
        }
    }
}

// MARK: - Helper Types

enum LiveAPIError: Error {
    case invalidURL
    case encodingError
    case decodingError
    case audioError(message: String)
    case permissionDenied
}

class AsyncQueue<T> {
    private var items: [T] = []
    private let maxSize: Int
    
    init(maxSize: Int) {
        self.maxSize = maxSize
    }
    
    func put(_ item: T) async throws {
        while items.count >= maxSize {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        items.append(item)
    }
    
    func get() async throws -> T {
        while items.isEmpty {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        return items.removeFirst()
    }
}