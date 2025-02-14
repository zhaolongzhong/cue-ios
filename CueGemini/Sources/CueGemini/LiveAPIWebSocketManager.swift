import Foundation
import AVFoundation
import OSLog
import Combine
import SwiftUI
import CueCommon

public final class LiveAPIWebSocketManager: NSObject, ObservableObject, URLSessionWebSocketDelegate, AudioManagerDelegate, @unchecked Sendable {
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private var apiKey: String = ""
    private let model = "gemini-2.0-flash-exp"
//    private let model = "gemini-2.0-pro-exp-02-05"
    private let host = "generativelanguage.googleapis.com"

    let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "LiveAPI",
                                category: "LiveAPIWebSocketManager")
    private let audioManager = AudioManager()
    private var isListening: Bool = false
    private var isServerTurn: Bool = false

    public override init() {
        super.init()
        setupSession()
        audioManager.delegate = self
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

    public func connect(apiKey: String) async throws {
        self.apiKey = apiKey

        // Initialize WebSocket
        // https://github.com/google-gemini/cookbook/blob/main/gemini-2/websockets/live_api_starter.py
        let wsURL = "wss://\(host)/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent?key=\(apiKey)"
        guard let url = URL(string: wsURL) else {
            logger.error("Invalid WebSocket URL: \(wsURL)")
            throw LiveAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let generationConfig = GenerationConfig(responseModalities: ["AUDIO"], speechConfig: SpeechConfig(voiceName: .aoede))

        self.webSocketTask = self.session?.webSocketTask(with: request)
        self.webSocketTask?.resume()
        self.logger.debug("WebSocket task resumed")

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

        try await audioManager.setupAudioEngine()
        receiveMessage()
    }

    func send<T: Encodable>(_ message: T) async throws { // allow extensions access
        guard let messageData = try? JSONEncoder().encode(message),
              let messageString = String(data: messageData, encoding: .utf8) else {
            logger.error("Failed to encode message to JSON")
            throw LiveAPIError.encodingError
        }

        logger.debug("Sending message: \(String(messageString.prefix(100)))")
        try await webSocketTask?.send(.string(messageString))
    }
    
    public func sendText(_ text: String) async throws {
        logger.debug("Sending text message: \(text)")
        let content = LiveAPIClientContent(client_content: .init(
            turnComplete: true,
            turns: [.init(
                role: "user",
                parts: [.init(text: text)]
            )]
        ))
        try await send(content)
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
                    self.receiveMessage()

                case .failure(let error):
                    self.logger.error("WebSocket receive error: \(error.localizedDescription)")
                }
            }
        }
    }

    private func handleTextMessage(_ text: String) async {
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
                    audioManager.playAudioData(decodedAudioData, id: "") // inx todo:
                } else {
                    logger.error("Failed to decode base64 audio data from serverContent")
                }
            }
            if let text = part.text {
                logger.debug("Received text from server: \(text)")
            }
        }
    }

    private func handleBinaryMessage(_ data: Data) async {
        guard let messageString = String(data: data, encoding: .utf8) else {
            logger.error("Failed to convert binary data to string")
            return
        }
        
        // Attempt to decode the string as LiveAPIResponse
        guard let jsonData = messageString.data(using: .utf8) else {
            logger.error("Failed to convert message string back to data")
            return
        }

        do {
            let response = try JSONDecoder().decode(LiveAPIResponse.self, from: jsonData)

            self.isListening = !(response.serverContent?.turnComplete == true)
            logger.debug("handleBinaryMessage turnComplete: \(String(describing: response.serverContent?.turnComplete))")

            if let serverContent = response.serverContent {
                if let modelTurn = serverContent.modelTurn {
                    if let part = modelTurn.parts?.first {
                        self.isServerTurn = true
                        if let inlineData = part.inlineData,
                           inlineData.mimeType.starts(with: "audio/pcm") {
                            if let decodedAudioData = Data(base64Encoded: inlineData.data) {
                                logger.debug("Received PCM audio data from serverContent")
                                audioManager.playAudioData(decodedAudioData, id: "inx") // inx todo
                            } else {
                                logger.error("Failed to decode base64 audio data from inlineData")
                            }
                        }

                        if let text = part.text {
                            logger.debug("Received text from serverContent: \(text)")
                        }
                    }
                }
            } else if response.setupComplete != nil {
                self.isServerTurn = false
                logger.debug("Received setupComplete message")
            } else {
                self.isServerTurn = false
                logger.error("Received serverContent without modelTurn or setupComplete")
            }
        } catch {
            logger.error("Failed to decode LiveAPIResponse: \(error.localizedDescription)")
            let hexString = data.map { String(format: "%02X", $0) }.joined(separator: " ")
            logger.debug("Raw binary data: \(hexString)")
        }
    }

    @MainActor
    public func disconnect() {
        self.logger.debug("WebSocket disconnect")
        self.webSocketTask?.cancel(with: .goingAway, reason: nil)
        self.audioManager.stopAudioEngine()
    }

    func checkIsServerTurn() -> Bool {
        return self.isServerTurn
    }
}

extension LiveAPIWebSocketManager {
    // MARK: - AudioManagerDelegate Methods

    public func audioManager(_ manager: AudioManager, didChangeState state: AudioManagerState) {
        self.logger.debug("audioManager didChangeState: \(state.description)")
    }

    public func audioManager(_ manager: AudioManager, didReceiveProcessedAudio data: Data) {
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
            } catch {
                self.logger.error("Failed to send audio data: \(error.localizedDescription)")
            }
        }
    }

    func audioManager(_ manager: AudioManager, didUpdatePlaybackState isPlaying: Bool) {
        Task { @MainActor in
            self.logger.debug("isPlaying updated to \(isPlaying)")
        }
    }
}
