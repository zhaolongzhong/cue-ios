import Foundation
import AVFoundation

enum OpenAIRealtimeError: Error {
    case invalidSession
    case invalidURL
    case networkError(Error)
    case audioSystemError(Error)
    case invalidConfiguration
}

actor OpenAIRealtimeAudioService: ObservableObject {
    // MARK: - Constants & Properties
    private let config: OpenAIRealtimeConfig
    private weak var delegate: OpenAIRealtimeDelegate?
    
    private var session: URLSession?
    private var webSocketTask: URLSessionWebSocketTask?
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var isRecording = false
    private var eventIdCounter = 0
    
    @Published private(set) var connectionState: ConnectionState = .disconnected {
        didSet {
            delegate?.connectionStateDidChange(connectionState)
        }
    }
    
    // MARK: - Initialization
    init(config: OpenAIRealtimeConfig, delegate: OpenAIRealtimeDelegate? = nil) {
        self.config = config
        self.delegate = delegate
    }
    
    // MARK: - Session Management
    func startSession() async throws {
        // 1. Configure audio session
        try await configureAudioSession()
        
        // 2. Create WebSocket session
        try await connectWebSocket()
        
        // 3. Configure session parameters
        try await configureSession()
        
        // 4. Setup audio engine
        try await setupAudioEngine()
        
        await updateConnectionState(.connected)
    }
    
    private func configureAudioSession() async throws {
        let session = AVAudioSession.sharedInstance()
        try await session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .defaultToSpeaker])
        try await session.setPreferredSampleRate(Double(config.sampleRate))
        try await session.setActive(true)
    }
    
    private func connectWebSocket() async throws {
        // Create session with OpenAI
        let sessionURL = URL(string: "wss://api.openai.com/v1/audio/streaming")!
        var request = URLRequest(url: sessionURL)
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        
        let session = URLSession(configuration: .default)
        let wsTask = session.webSocketTask(with: request)
        
        self.session = session
        self.webSocketTask = wsTask
        
        wsTask.resume()
        
        // Start receiving messages
        await receiveMessages()
    }
    
    private func configureSession() async throws {
        guard let wsTask = webSocketTask else {
            throw OpenAIRealtimeError.invalidConfiguration
        }
        
        // Prepare audio configuration
        let audioConfig = [
            "type": "audio_config",
            "encoding": "s16le",                // 16-bit PCM (little-endian)
            "sample_rate": config.sampleRate,
            "language_code": config.languageCode,
            "model": config.model,
            "api_key": config.apiKey
        ] as [String : Any]
        
        // Prepare VAD configuration
        let vadConfig = [
            "type": "vad_config",
            "silence_threshold_ms": config.silenceThresholdMs,
            "speech_threshold_ms": config.speechThresholdMs
        ]
        
        // Send session configuration
        let configMessage = [
            "type": "session_config",
            "event_id": generateEventId(),
            "config": audioConfig,
            "vad": vadConfig
        ]
        
        try await sendJSONMessage(configMessage)
    }
    
    // MARK: - Audio Processing
    private func setupAudioEngine() async throws {
        let audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode
        
        // Configure format for 16kHz, 16-bit mono PCM
        let desiredFormat = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                        sampleRate: Double(config.sampleRate),
                                        channels: 1,
                                        interleaved: true)!
        
        let converter = AVAudioConverter(from: inputNode.outputFormat(forBus: 0),
                                       to: desiredFormat)!
        
        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputNode.outputFormat(forBus: 0)) { [weak self] buffer, time in
            // Convert audio buffer to appropriate format and send via WebSocket
            Task {
                await self?.processAudioBuffer(buffer, converter: converter)
            }
        }
        
        try audioEngine.start()
        
        self.audioEngine = audioEngine
        self.inputNode = inputNode
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, converter: AVAudioConverter) async {
        guard let wsTask = webSocketTask,
              connectionState == .connected else { return }
        
        // Convert to desired format (16kHz, 16-bit mono PCM)
        let convertedBuffer = AVAudioPCMBuffer(pcmFormat: converter.outputFormat,
                                             frameCapacity: AVAudioFrameCount(Double(buffer.frameLength) * converter.outputFormat.sampleRate / converter.inputFormat.sampleRate))!
        
        var error: NSError?
        let status = converter.convert(to: convertedBuffer, error: &error) { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        guard status != .error, error == nil else {
            print("Conversion error: \(error?.localizedDescription ?? "unknown error")")
            return
        }
        
        // Create audio chunk message
        let message = [
            "type": "audio_chunk",
            "event_id": generateEventId(),
            "audio_data": convertedBuffer.data.base64EncodedString(),
            "timestamp": Date().timeIntervalSince1970
        ]
        
        do {
            try await sendJSONMessage(message)
        } catch {
            print("Error sending audio data: \(error)")
        }
    }
    
    // MARK: - Message Handling
    private func receiveMessages() async {
        guard let wsTask = webSocketTask else { return }
        
        do {
            let message = try await wsTask.receive()
            switch message {
            case .string(let text):
                try await handleServerMessage(text)
            case .data(let data):
                print("Received binary data of size: \(data.count)")
            @unknown default:
                break
            }
            
            // Continue receiving messages
            await receiveMessages()
        } catch {
            print("Error receiving message: \(error)")
            await updateConnectionState(.disconnected)
        }
    }
    
    @MainActor
    private func handleServerMessage(_ text: String) async throws {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let messageType = json["type"] as? String else {
            return
        }
        
        switch messageType {
        case "session_confirmed":
            print("Session configuration confirmed")
            
        case "speech_started":
            print("Speech detected")
            delegate?.speechDetected()
            
        case "speech_ended":
            print("Speech ended")
            delegate?.speechEnded()
            
        case "transcription":
            if let text = json["text"] as? String {
                print("Transcription: \(text)")
                delegate?.didReceiveTranscription(text)
            }
            
        case "error":
            if let error = json["error"] as? String {
                print("Server error: \(error)")
                let error = OpenAIRealtimeError.networkError(NSError(domain: "OpenAIRealtime", 
                                                                   code: -1, 
                                                                   userInfo: [NSLocalizedDescriptionKey: error]))
                delegate?.didEncounterError(error)
            }
            
        default:
            print("Unknown message type: \(messageType)")
        }
    }
    
    // MARK: - Utilities
    private func generateEventId() -> String {
        eventIdCounter += 1
        return "evt_\(eventIdCounter)"
    }
    
    private func sendJSONMessage(_ message: [String: Any]) async throws {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: message),
              let jsonString = String(data: jsonData, encoding: .utf8),
              let wsTask = webSocketTask else {
            throw OpenAIRealtimeError.invalidConfiguration
        }
        
        try await wsTask.send(.string(jsonString))
    }
    
    func stopSession() async {
        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)
        
        // Send end session message
        if connectionState == .connected {
            let message = [
                "type": "end_session",
                "event_id": generateEventId()
            ]
            
            try? await sendJSONMessage(message)
        }
        
        webSocketTask?.cancel()
        await updateConnectionState(.disconnected)
    }
    
    @MainActor
    private func updateConnectionState(_ newState: ConnectionState) {
        connectionState = newState
    }
}

// MARK: - Supporting Types
private extension AVAudioPCMBuffer {
    var data: Data {
        // Convert audio buffer to Data
        guard let ptr = int16ChannelData else { return Data() }
        let buf = UnsafeBufferPointer(start: ptr[0], count: Int(frameLength))
        return Data(buffer: buf)
    }
}