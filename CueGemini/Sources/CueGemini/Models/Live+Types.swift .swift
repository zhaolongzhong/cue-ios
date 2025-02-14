import Foundation

public enum Modality: String, Codable, Equatable, Sendable {
    case audio
    case text
}

struct LiveAPISetup: Encodable {
    let setup: SetupDetails
}

struct SetupDetails: Encodable {
    let model: String
    let generationConfig: GenerationConfig?
    let systemInstruction: String?
    let tools: [LiveAPITool]?

    enum CodingKeys: String, CodingKey {
        case model = "model"
        case generationConfig = "generation_config"
        case systemInstruction = "system_instruction"
        case tools = "tools"
    }
}

struct GenerationConfig: Encodable {
    let candidateCount: Int?
    let maxOutputTokens: Int?
    let temperature: Double?
    let topP: Double?
    let topK: Int?
    let presencePenalty: Double?
    let frequencyPenalty: Double?
    let responseModalities: [String]?
    let speechConfig: SpeechConfig?

    init(
        candidateCount: Int? = nil,
        maxOutputTokens: Int? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        topK: Int? = nil,
        presencePenalty: Double? = nil,
        frequencyPenalty: Double? = nil,
        responseModalities: [String]? = nil,
        speechConfig: SpeechConfig? = nil
    ) {
        self.candidateCount = candidateCount
        self.maxOutputTokens = maxOutputTokens
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.presencePenalty = presencePenalty
        self.frequencyPenalty = frequencyPenalty
        self.responseModalities = responseModalities
        self.speechConfig = speechConfig
    }

    enum CodingKeys: String, CodingKey {
        case candidateCount = "candidate_count"
        case maxOutputTokens = "max_output_tokens"
        case temperature = "temperature"
        case topP = "top_p"
        case topK = "top_k"
        case presencePenalty = "presence_penalty"
        case frequencyPenalty = "frequency_penalty"
        case responseModalities = "response_modalities"
        case speechConfig = "speech_config"
    }
}

struct SpeechConfig: Encodable {
    let voiceConfig: VoiceConfig
    
    init(voiceName: Voice) {
        self.voiceConfig = VoiceConfig(prebuiltVoiceConfig: PrebuiltVoiceConfig(voiceName: voiceName))
    }
}

struct VoiceConfig: Encodable {
    let prebuiltVoiceConfig: PrebuiltVoiceConfig
}

struct PrebuiltVoiceConfig: Encodable {
    let voiceName: Voice
    
    enum CodingKeys: String, CodingKey {
        case voiceName = "voiceName"
    }
}

enum Voice: String, Encodable {
    case puck = "Puck"
    case charon = "Charon"
    case kore = "Kore"
    case fenrir = "Fenrir"
    case aoede = "Aoede"
}

struct FunctionSchema: Codable {
    let name: String
}

struct LiveAPITool: Codable {
    let googleSearch: [String: String]?
        let codeExecution: [String: String]?
        let functionDeclarations: [FunctionSchema]?

        enum CodingKeys: String, CodingKey {
            case googleSearch = "google_search"
            case codeExecution = "code_execution"
            case functionDeclarations = "function_declarations"
        }
}

struct LiveAPIResponse: Decodable {
    let serverContent: ServerContent?
    let setupComplete: SetupComplete?

    enum CodingKeys: String, CodingKey {
        case serverContent = "serverContent"
        case setupComplete = "setupComplete"
    }
}

struct SetupComplete: Decodable {}

struct ServerContent: Decodable {
    let modelTurn: ModelTurn?
    let turnComplete: Bool?

    enum CodingKeys: String, CodingKey {
        case modelTurn = "modelTurn"
        case turnComplete = "turnComplete"
    }
}

struct ModelTurn: Decodable {
    let parts: [Part]?
}

struct Part: Decodable {
    let text: String?
    let inlineData: InlineData?

    enum CodingKeys: String, CodingKey {
        case text
        case inlineData = "inlineData"
    }
}

struct InlineData: Decodable {
    let mimeType: String
    let data: String

    enum CodingKeys: String, CodingKey {
        case mimeType = "mimeType"
        case data
    }
}

struct BinaryMessage: Decodable {
    let setupComplete: SetupComplete?
    let serverContent: ServerContent?

    enum CodingKeys: String, CodingKey {
        case setupComplete = "setupComplete"
        case serverContent = "serverContent"
    }
}

struct LiveAPIContent: Decodable {
    let audio: AudioData?
    let text: String?
    // Add other fields if present
}

struct AudioData: Decodable {
    let mimeType: String
    let data: String

    enum CodingKeys: String, CodingKey {
        case mimeType = "mime_type"
        case data
    }
}

struct LiveAPIMetadata: Decodable {
    let timestamp: String?
    // Add other fields as necessary
}

// MARK: - LiveAPIClientContent Struct

struct LiveAPIClientContent: Encodable {
    let client_content: ClientContent

    enum CodingKeys: String, CodingKey {
        case client_content = "clientContent"
    }

    struct ClientContent: Encodable {
        let turnComplete: Bool
        let turns: [Turn]

        struct Turn: Encodable {
            let role: String
            let parts: [Part]

            struct Part: Encodable {
                let text: String?
            }
        }
    }
}

struct LiveAPIRealtimeInput: Encodable {
    let realtimeInput: RealtimeInput

    struct RealtimeInput: Encodable {
        let mediaChunks: [MediaChunk]

        struct MediaChunk: Encodable {
            let mimeType: String
            let data: String
        }
    }
}

enum LiveAPIError: Error {
    case invalidURL
    case encodingError
    case audioError(message: String)
}
