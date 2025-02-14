/// https://github.com/google-gemini/generative-ai-swift/blob/main/Sources/GoogleAI/GenerationConfig.swift
import Foundation

public struct GenerationConfig: Encodable, Sendable {
    let candidateCount: Int?
    let maxOutputTokens: Int?
    let temperature: Double?
    let topP: Double?
    let topK: Int?
    let presencePenalty: Double?
    let frequencyPenalty: Double?
    let responseModalities: [Modality]?
    let speechConfig: SpeechConfig?

    public init(
        candidateCount: Int? = nil,
        maxOutputTokens: Int? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        topK: Int? = nil,
        presencePenalty: Double? = nil,
        frequencyPenalty: Double? = nil,
        responseModalities: [Modality]? = nil,
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

public enum Modality: String, Codable, Equatable, Sendable {
    case audio
    case text
}

public struct SpeechConfig: Encodable, Sendable {
    let voiceConfig: VoiceConfig
    
    public init(voiceName: Voice) {
        self.voiceConfig = VoiceConfig(prebuiltVoiceConfig: PrebuiltVoiceConfig(voiceName: voiceName))
    }
}

public struct VoiceConfig: Encodable, Sendable {
    let prebuiltVoiceConfig: PrebuiltVoiceConfig
}

public struct PrebuiltVoiceConfig: Encodable, Sendable {
    let voiceName: Voice
    
    public init(voiceName: Voice) {
        self.voiceName = voiceName
    }
    
    enum CodingKeys: String, CodingKey {
        case voiceName = "voiceName"
    }
}

public enum Voice: String, Encodable, Sendable {
    case puck = "Puck"
    case charon = "Charon"
    case kore = "Kore"
    case fenrir = "Fenrir"
    case aoede = "Aoede"
}
