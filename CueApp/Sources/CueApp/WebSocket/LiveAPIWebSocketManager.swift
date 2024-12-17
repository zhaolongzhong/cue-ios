import Foundation
import AVFoundation
import os.log
import Combine
import SwiftUI

// MARK: - LiveAPIWebSocketManager Class

final class LiveAPIWebSocketManager: NSObject, ObservableObject, URLSessionWebSocketDelegate, AudioManagerDelegate, @unchecked Sendable {
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
    private var isListening: Bool = false
    private var isServerTurn: Bool = false
    
    @MainActor private var screenManager: ScreenManager!
    var isScreenCapturing = false
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupSession()
        audioManager.delegate = self
        // Initialize ScreenManager on main thread
        Task { @MainActor in
            self.screenManager = ScreenManager()
            self.screenManager.delegate = self
        }
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
        let generationConfig = GenerationConfig(responseModalities: ["AUDIO"])
        
        webSocketQueue.async { [weak self] in
            guard let self = self else { return }
            self.webSocketTask = self.session?.webSocketTask(with: request)
            self.webSocketTask?.resume()
            self.logger.debug("WebSocket task resumed")
            
            // Send initial setup message with only the model inside "setup"
            
            // Create the tools
            let turnOnTheLightsSchema = FunctionSchema(name: "turn_on_the_lights")
            let turnOffTheLightsSchema = FunctionSchema(name: "turn_off_the_lights")

            let tools = [
                LiveAPITool(googleSearch: [:], codeExecution: nil, functionDeclarations: nil),
                LiveAPITool(googleSearch: nil, codeExecution: [:], functionDeclarations: nil),
                LiveAPITool(googleSearch: nil, codeExecution: nil, functionDeclarations: [turnOnTheLightsSchema, turnOffTheLightsSchema])
            ]
            
            let setup = LiveAPISetup(
                setup: SetupDetails(
                    model: "models/\(self.model)",
                    generationConfig: generationConfig,
                    systemInstruction: nil,
                    tools: tools
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
//        logger.debug("Sending message: \(String(messageString.prefix(100)))")
        
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
        logger.debug("inx Received text message: \(text)")
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
//        logger.debug("Received binary message of size: \(data.count) bytes")
        
        // Attempt to convert binary data to string
        guard let messageString = String(data: data, encoding: .utf8) else {
            logger.error("Failed to convert binary data to string")
            return
        }
        
//        logger.debug("inx Binary message as string: \(String(messageString.prefix(200)))")
        
        // Attempt to decode the string as LiveAPIResponse
        guard let jsonData = messageString.data(using: .utf8) else {
            logger.error("Failed to convert message string back to data")
            return
        }
        
        do {
            let response = try JSONDecoder().decode(LiveAPIResponse.self, from: jsonData)
            
            self.isListening = !(response.serverContent?.turnComplete == true)
            if let turnComplete = response.serverContent?.turnComplete {
//                logger.debug("inx handleBinaryMessage turnComplete: \(turnComplete), set audioManager.turnComplete = true")
                audioManager.turnComplete = true
            } else {
//                logger.debug("inx handleBinaryMessage turnComplete: nil, set audioManager.turnComplete = false")
                audioManager.turnComplete = false
            }
            
            if let serverContent = response.serverContent {
                if let modelTurn = serverContent.modelTurn {
                    if let part = modelTurn.parts?.first {
                        self.isServerTurn = true
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
                    }
                } else if let turnComplete = serverContent.turnComplete {
                    self.isServerTurn = false
                } else {
                    self.isServerTurn = false
                    logger.error("Unexpected state received from serverContent")
                }
            } else if response.setupComplete != nil {
                self.isServerTurn = false
                logger.debug("Received setupComplete message")
                // Handle setup completion if needed
            } else {
                self.isServerTurn = false
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
    
    func checkIsServerTurn() -> Bool {
        return self.isServerTurn
    }
}



// Add ScreenManagerDelegate conformance
extension LiveAPIWebSocketManager: ScreenManagerDelegate {
    
//    // Add new method for starting screen capture
//    func startScreenCapture() async throws {
//        guard !isScreenCapturing else { return }
//        
//        #if os(macOS)
//        try await screenManager.startCapturingMacScreen()
//        #elseif os(iOS)
//        try await screenManager.startCapturingIOSScreen()
//        #endif
//        
//        isScreenCapturing = true
//    }
//
//    // Add new method for stopping screen capture
//    func stopScreenCapture() async {
//        guard isScreenCapturing else { return }
//        await screenManager.stopCapturing()
//        isScreenCapturing = false
//    }
        
    func screenManager(_ manager: ScreenManager, didReceiveFrame data: Data) {
        Task {
            let base64Data = data.base64EncodedString()
            
            let chunk = LiveAPIRealtimeInput.RealtimeInput.MediaChunk(
                mimeType: "image/jpeg",
                data: base64Data
            )
            let input = LiveAPIRealtimeInput(realtimeInput: .init(mediaChunks: [chunk]))
            
            do {
                try await self.send(input)
                self.logger.debug("Sent screen frame data")
            } catch {
                self.logger.error("Failed to send screen frame: \(error.localizedDescription)")
            }
        }
    }
}


extension LiveAPIWebSocketManager {
    func startScreenCapture() async throws {
        guard !isScreenCapturing else { return }
        
        let isAvailable = await screenManager.requestScreenCapturePermission()
        guard isAvailable else {
            throw ScreenCaptureError.permissionDenied
        }
        
        try await screenManager.startCapturingIOSScreen()
        isScreenCapturing = true
    }
    
    func stopScreenCapture() async {
        guard isScreenCapturing else { return }
        await screenManager.stopCapturing()
        isScreenCapturing = false
    }
}

// 3. Update LiveAPIWebSocketManager with background handling
extension LiveAPIWebSocketManager {
    func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            Task { @MainActor in
                if isScreenCapturing {
                    // Start a long-running background task
                    await BackgroundTaskManager.shared.startBackgroundTask(identifier: "screenCapture") {
                        Task {
                            await self.stopScreenCapture()
                        }
                    }
                    
                    // Configure for background operation
                    await screenManager.prepareForBackground()
                }
            }
            
        case .active:
            Task { @MainActor in
                if isScreenCapturing {
                    // Restore normal operation
                    await screenManager.prepareForForeground()
                }
            }
            
        default:
            break
        }
    }
}
