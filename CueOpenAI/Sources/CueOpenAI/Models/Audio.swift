import Foundation

public struct InputAudioTranscription: Codable, Equatable, Sendable {
    let model: String // whisper-1 is the only currently supported model
}

public enum Voice: String, Codable, Equatable, Sendable {
    case alloy, ash, ballad, coral, echo, sage, shimmer, verse
}

public enum AudioFormat: String, Codable, Equatable, Sendable {
    case pcm16
    case g711Ulaw = "g711_ulaw"
    case g711Alaw = "g711_alaw"
}


