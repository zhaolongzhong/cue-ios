import Foundation
import AVFoundation
import os.log
import Combine

// MARK: - LiveAPIWebSocketManager Class

final class LiveAPIWebSocketManager: NSObject, URLSessionWebSocketDelegate, AudioManagerDelegate, @unchecked Sendable {
    // MARK: - Properties
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    
    private var apiKey: String = ""
    private let model = "gemini-2.0-flash-exp"
    private let host = "generativelanguage.googleapis.com"
    
    let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "LiveAPI",
                                category: "LiveAPIWebSocketManager")
    
    // Queues for audio/video processing
    private var audioInQueue: AsyncQueue<Data>?
    private var outQueue: AsyncQueue<Data>?
    
    @Published private(set) var isPlaying: Bool = false
    private var isAudioSetup = false
    
    // Dedicated background queues for thread safety
    private let webSocketQueue = DispatchQueue(label: "com.yourapp.webSocketQueue")
    private let audioProcessingQueue = DispatchQueue(label: "com.yourapp.audioProcessingQueue")
    
    // Audio Manager
    private let audioManager = AudioManager()
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupSession()
        audioManager.delegate = self
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
    
    // MARK: - Connect Method
    
    func connect(apiKey: String) async throws {
        self.apiKey = apiKey
        
        // Initialize WebSocket
        let wsURL = "wss://\(host)/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent?key=\(apiKey)"
        guard let url = URL(string: wsURL) else {
            logger.error("Invalid WebSocket URL: \(wsURL)")
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
            try await audioManager.setupAudioEngine()
            isAudioSetup = true
            logger.debug("Audio engine setup completed and marked as setup")
        }
        
        // Start receiving messages
        receiveMessage()
    }
    
    // MARK: - Send Method
    
    func send<T: Encodable>(_ message: T) async throws { // allow extensions access
        guard let messageData = try? JSONEncoder().encode(message),
              let messageString = String(data: messageData, encoding: .utf8) else {
            logger.error("Failed to encode message to JSON")
            throw LiveAPIError.encodingError
        }
        
        // Log the message being sent
        logger.debug("Sending message: \(String(messageString.prefix(100)))")
        
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
                    await audioManager.playAudioData(decodedAudioData)
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
        
        logger.debug("Binary message as string: \(String(messageString.prefix(200)))")
        
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
                        await audioManager.playAudioData(decodedAudioData)
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
            self.audioManager.stopAudioEngine()
            self.logger.debug("Audio engine stopped via AudioManager")
        }
        
        isPlaying = false
        isAudioSetup = false
        logger.debug("isPlaying set to false and isAudioSetup set to false")
    }
    
    // MARK: - AudioManagerDelegate Methods
    
    func audioManager(_ manager: AudioManager, didReceiveProcessedAudio data: Data) {
        Task { [weak self] in
            guard let self = self else { return }
            let base64Data = data.base64EncodedString()
            
            let chunk = LiveAPIRealtimeInput.RealtimeInput.MediaChunk(
                mimeType: "audio/pcm",
                data: base64Data
            )
            let input = LiveAPIRealtimeInput(realtimeInput: .init(mediaChunks: [chunk]))
            
            do {
                try await self.send(input)
                self.logger.debug("Sent processed audio data")
            } catch {
                self.logger.error("Failed to send audio data: \(error.localizedDescription)")
            }
        }
    }
    
    func audioManager(_ manager: AudioManager, didUpdatePlaybackState isPlaying: Bool) {
        Task { @MainActor in
            self.isPlaying = isPlaying
            self.logger.debug("isPlaying updated to \(isPlaying)")
        }
    }
}
