import Foundation
import os.log

public protocol RealtimeAPIProtocol: Sendable {
    func createConnection(config: RealtimeConfig, sessionCreate: RealtimeSession?) async throws -> RealtimeConnectionProtocol
}

public final class RealtimeAPI: RealtimeAPIProtocol, Sendable {
    private let baseURL = "https://api.openai.com/v1/realtime"
    private let webSocketBaseURL = "wss://api.openai.com/v1/realtime"
    
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()
    
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
    
    private let logger = Logger(subsystem: "RealtimeAPI", category: "RealtimeAPI")
    private let transport: RealtimeTransport
    
    public init(transport: RealtimeTransport = .webSocket) {
        self.transport = transport
    }
    
    public func createConnection(config: RealtimeConfig, sessionCreate: RealtimeSession? = nil) async throws -> RealtimeConnectionProtocol {
        if transport == .webSocket {
            let urlRequest = try await createWebSocketURLRequest(config: config)
            return WebSocketConnection(urlRequest: urlRequest)
        } else {
            let urlRequest = try await createWebRTCURLRequest(config: config)
            return WebRTCConnection(urlRequest: urlRequest)
        }
    }
    
    private func createSession(config: RealtimeConfig, sessionCreate: RealtimeSession? = nil) async throws -> SessionResponse {
        let sessionRequest = sessionCreate ?? RealtimeSession.defaultRealtimeSession(model: config.model)
        var urlRequest = URLRequest(url: URL(string: "\(baseURL)/sessions")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try encoder.encode(sessionRequest)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIServiceError.invalidResponse
        }
        
        guard 200..<300 ~= httpResponse.statusCode else {
            let serverMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw OpenAIServiceError.serverError(message: serverMessage, statusCode: httpResponse.statusCode)
        }
        
        return try decoder.decode(SessionResponse.self, from: data)
    }
    
    public func createWebSocketURLRequest(config: RealtimeConfig) async throws -> URLRequest {
        // https://platform.openai.com/docs/guides/realtime-websocket#connection-details
        var request = URLRequest(url: URL(string: webSocketBaseURL)!.appending(queryItems: [
            URLQueryItem(name: "model", value: config.model),
        ]))
        // a standard API key on the server, or an ephemeral token on insecure clients
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("realtime=v1", forHTTPHeaderField: "OpenAI-Beta")
        return request
    }
    
    public func createWebRTCURLRequest(config: RealtimeConfig, sessionCreate: RealtimeSession? = nil) async throws -> URLRequest {
        let sessionResponse = try await createSession(config: config, sessionCreate: sessionCreate)
        guard let clientSecret = sessionResponse.clientSecret else {
            let errorMessage = "Failed to create client secret"
            logger.error("Failed to create client secret: \(errorMessage)")
            throw OpenAIServiceError.invalidCrendential
        }
        
        // https://platform.openai.com/docs/guides/realtime-webrtc#connection-details
        var request = URLRequest(url: URL(string: baseURL)!.appending(queryItems: [
            URLQueryItem(name: "model", value: config.model),
        ]))

        let ephemeralKey = clientSecret.value
        request.addValue("realtime=v1", forHTTPHeaderField: "OpenAI-Beta")
        request.addValue("Bearer \(ephemeralKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/sdp", forHTTPHeaderField: "Content-Type")
        
        return request
    }
}

extension RealtimeSession {
    static func defaultRealtimeSession(model: String) -> RealtimeSession {
        return RealtimeSession(
            model: model,
            modalities: [.text, .audio],
            instructions: "You are a helpful assistant.",
            voice: "alloy",
            inputAudioFormat: "pcm16",
            outputAudioFormat: "pcm16",
            inputAudioTranscription: InputAudioTranscription(model: "whisper-1"),
            turnDetection: TurnDetection(type: "server_vad", threshold: 0.9, prefixPaddingMs: 500, silenceDurationMs: 2000, createResponse: false),
            tools: [],
            toolChoice: "auto",
            temperature: 0.8,
            maxResponseOutputTokens: nil
        )
    }
}

enum OpenAIServiceError: LocalizedError {
    case invalidCrendential
    case invalidResponse
    case serverError(message: String, statusCode: Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidCrendential:
            return "Invalid credneital configuration"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let message, let statusCode):
            return "Server error (\(statusCode)): \(message)"
        }
    }
}
