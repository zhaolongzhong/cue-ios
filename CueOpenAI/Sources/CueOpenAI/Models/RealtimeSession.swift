
public struct RealtimeSession: Codable, Equatable, Sendable {
    let model: String
    let modalities: [Modality]?
    let instructions: String?
    let voice: String?
    let inputAudioFormat: String?
    let outputAudioFormat: String?
    let inputAudioTranscription: InputAudioTranscription?
    let turnDetection: TurnDetection?
    let tools: [FunctionDefinition]?
    let toolChoice: String?
    let temperature: Double?
    let maxResponseOutputTokens: IntOrInf?
}

public struct ClientSecret: Codable, Sendable {
    let value: String
    let expiresAt: Int
}

public enum Modality: String, Codable, Equatable, Sendable {
    case audio
    case text
}

public struct TurnDetection: Codable, Equatable, Sendable {
    public let type: String?
    public let threshold: Double?
    public let prefixPaddingMs: Int?
    public let silenceDurationMs: Int?
    public let createResponse: Bool?
}

public struct SessionCreatedEvent: Decodable, Sendable {
    public let eventId: String
    public let type: String
    public let session: SessionResponse
}

public struct SessionUpdatedEvent: Decodable, Sendable {
    public let eventId: String
    public let type: String
    public let session: SessionResponse
}

public enum IntOrInf: Codable, Equatable, Sendable {
    case int(Int)
    case infinity
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else if let stringValue = try? container.decode(String.self), stringValue == "inf" {
            self = .infinity
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected Int or 'inf'")
        }
    }
}

public struct SessionResponse: Decodable, Sendable {
    public let id: String
    public let object: String
    public let model: String
    public let modalities: [Modality]
    public let instructions: String
    public let voice: String
    public let inputAudioFormat: String
    public let outputAudioFormat: String
    public let inputAudioTranscription: InputAudioTranscription?
    public let turnDetection: TurnDetection?
    public let tools: [FunctionDefinition]
    public let toolChoice: String
    public let temperature: Double
    public let maxResponseOutputTokens: IntOrInf
    public let clientSecret: ClientSecret?
}
