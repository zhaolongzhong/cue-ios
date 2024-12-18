import Foundation
@preconcurrency import AVFoundation
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
    // https://cloud.google.com/vertex-ai/generative-ai/docs/model-reference/multimodal-live#audio-formats
    // Multimodal Live API supports the following audio formats:
    // - Input audio format: Raw 16 bit PCM audio at 16kHz little-endian
    // - Output audio format: Raw 16 bit PCM audio at 24kHz little-endian
    private let RECEIVE_SAMPLE_RATE: Double = 24000 // 24kHz as per latest requirements
    private let SEND_SAMPLE_RATE: Double = 16000 // 16kHz as per latest requirements
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
    
    #if os(iOS)
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
    #endif
    
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
            // Configure AVAudioSession for 16kHz, 16-bit PCM with voice chat mode
            #if os(iOS)
            let session = AVAudioSession.sharedInstance()
            try await MainActor.run {
                try session.setCategory(.playAndRecord,
                                        mode: .voiceChat, // Changed to .voiceChat for echo cancellation
                                        options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP])
                try session.setPreferredSampleRate(SEND_SAMPLE_RATE) // 16kHz
                try session.setActive(true)
                self.logger.debug("Audio session category set to .voiceChat and activated.")
                self.logger.debug("Preferred sample rate: \(self.SEND_SAMPLE_RATE) Hz")
                self.logger.debug("Actual sample rate: \(session.sampleRate) Hz")
            }
            //            let actualSampleRate = session.sampleRate
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
                throw LiveAPIError.audioError(message: "Failed to create input audio format")
            }
            
            logger.debug("Input AudioFormat created with sampleRate: \(inputAudioFormat.sampleRate) Hz, channels: \(inputAudioFormat.channelCount)")
            
            // Initialize format for the main mixer node (Float32 at actualSampleRate)
            audioFormat = AVAudioFormat(standardFormatWithSampleRate: actualSampleRate, channels: CHANNELS)
            
            guard let audioFormat = audioFormat else {
                throw LiveAPIError.audioError(message: "Failed to create audio format")
            }
            
            logger.debug("AudioFormat created with sampleRate: \(audioFormat.sampleRate) Hz, channels: \(audioFormat.channelCount)")
            
            // Attach and connect player node directly to main mixer
            audioEngine.attach(playerNode)
            audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: audioFormat)
            logger.debug("Connected playerNode to mainMixerNode")
            
            // Install tap on input node with the hardware's actual format
            audioEngine.inputNode.installTap(onBus: 0,
                                             bufferSize: 1024,
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
        } catch {
            logger.error("Error setting up audio engine: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Convert and Send Audio Buffer

    private func convertAndSend(buffer: AVAudioPCMBuffer) {
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
        
        // Send the processed audio data
        Task { @MainActor in
            await self.handleProcessedAudioData(int16Data)
        }
    }

    // MARK: - Play Audio Data with Correct Format Handling

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
        
        // Perform Resampling and conversion to Float32 at 48kHz
        let destinationFormatSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: RECEIVE_SAMPLE_RATE, // 24kHz, but adjusted below
            AVNumberOfChannelsKey: CHANNELS,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: true,
        ]
        
        // Adjust destination sample rate to match audio session's actual sample rate
        let destinationSampleRate = audioFormat.sampleRate // 48kHz
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
        let ratio = destinationFormat.sampleRate / sourceSampleRate // 48kHz / 24kHz = 2.0
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
            self?.logger.debug("Completed playing converted buffer of \(destinationBuffer.frameLength) frames")
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
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setActive(false)
            logger.debug("Audio session deactivated")
        } catch {
            logger.error("Failed to deactivate audio session: \(error.localizedDescription)")
        }
        #endif
        
        isPlaying = false
        isAudioSetup = false
        logger.debug("isPlaying set to false and isAudioSetup set to false")
    }
}


// MARK: - Helper Function for Resampling (Optional)

extension LiveAPIWebSocketManager {
    // Helper function to convert AVAudioPCMBuffer from source to destination format
    private func convertBuffer(_ buffer: AVAudioPCMBuffer, from sourceFormat: AVAudioFormat, to destinationFormat: AVAudioFormat) throws -> AVAudioPCMBuffer {
        guard let converter = AVAudioConverter(from: sourceFormat, to: destinationFormat) else {
            throw LiveAPIError.audioError(message: "Failed to create AVAudioConverter")
        }
        
        let ratio = destinationFormat.sampleRate / sourceFormat.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: destinationFormat, frameCapacity: outputFrameCapacity) else {
            throw LiveAPIError.audioError(message: "Failed to create converted PCM buffer")
        }
        
        convertedBuffer.frameLength = 0 // Initialize buffer
        
        var error: NSError?
        let status = converter.convert(to: convertedBuffer, error: &error) { inNumPackets, outStatus in
            outStatus.pointee = AVAudioConverterInputStatus.haveData
            return buffer
        }
        
        if status == .error {
            throw error ?? LiveAPIError.audioError(message: "Unknown conversion error")
        }
        
        // Calculate the number of frames after conversion
        let convertedFrames = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        convertedBuffer.frameLength = convertedFrames
        
        return convertedBuffer
    }
}
