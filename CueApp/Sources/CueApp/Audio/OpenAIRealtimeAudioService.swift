import Foundation
import AVFoundation

enum OpenAIRealtimeError: Error {
    case invalidSession
    case invalidURL
    case networkError(Error)
    case audioSystemError(Error)
}

actor OpenAIRealtimeAudioService: ObservableObject {
    private var apiKey: String
    private var session: URLSession?
    private var webSocketTask: URLSessionWebSocketTask?
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var isRecording = false
    
    @Published private(set) var connectionState: ConnectionState = .disconnected
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func startSession() async throws {
        // 1. Create session with OpenAI
        let sessionURL = URL(string: "https://api.openai.com/v1/realtime/sessions")!
        var request = URLRequest(url: sessionURL)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OpenAIRealtimeError.invalidSession
        }
        
        let sessionResponse = try JSONDecoder().decode(RealtimeSessionResponse.self, from: data)
        
        // 2. Setup WebSocket connection
        guard let wsURL = URL(string: sessionResponse.url) else {
            throw OpenAIRealtimeError.invalidURL
        }
        
        let session = URLSession(configuration: .default)
        let wsTask = session.webSocketTask(with: wsURL)
        
        self.session = session
        self.webSocketTask = wsTask
        
        wsTask.resume()
        
        // Start receiving messages
        await receiveMessages()
        
        // 3. Setup audio engine
        try await setupAudioEngine()
        
        await updateConnectionState(.connected)
    }
    
    private func setupAudioEngine() async throws {
        let audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, time in
            // Convert audio buffer to appropriate format and send via WebSocket
            Task {
                await self?.processAudioBuffer(buffer)
            }
        }
        
        try audioEngine.start()
        
        self.audioEngine = audioEngine
        self.inputNode = inputNode
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) async {
        // Convert buffer to appropriate format for OpenAI
        // Send via WebSocket
        guard let wsTask = webSocketTask,
              connectionState == .connected else { return }
        
        // TODO: Convert buffer to required format
        // Example: Convert to 16-bit PCM
        
        let message = URLSessionWebSocketTask.Message.data(buffer.data)
        do {
            try await wsTask.send(message)
        } catch {
            print("Error sending audio data: \(error)")
        }
    }
    
    private func receiveMessages() async {
        guard let wsTask = webSocketTask else { return }
        
        do {
            let message = try await wsTask.receive()
            switch message {
            case .string(let text):
                print("Received text message: \(text)")
            case .data(let data):
                print("Received binary message of size: \(data.count)")
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
    
    func stopSession() async {
        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)
        webSocketTask?.cancel()
        await updateConnectionState(.disconnected)
    }
    
    @MainActor
    private func updateConnectionState(_ newState: ConnectionState) {
        connectionState = newState
    }
}

// MARK: - Supporting Types

struct RealtimeSessionResponse: Codable {
    let url: String
}

private extension AVAudioPCMBuffer {
    var data: Data {
        // Convert audio buffer to Data
        // This is a simplified implementation
        guard let ptr = int16ChannelData else { return Data() }
        let buf = UnsafeBufferPointer(start: ptr[0], count: Int(frameLength))
        return Data(buffer: buf)
    }
}