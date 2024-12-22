public struct ContentPart: Codable, Equatable, Sendable {
    public let type: ContentType
    public let text: String? // used for input_text and text
    public let id: String? // ID of a previous conversation item to reference (for item_reference
    public let audio: String? // used for input_audio content type
    public let transcript: String? // used for input_audio content type
    
    public init(
        type: ContentType,
        text: String? = nil,
        id: String? = nil,
        audio: String? = nil,
        transcript: String? = nil
    ) {
        self.type = type
        self.text = text
        self.id = id
        self.audio = audio
        self.transcript = transcript
    }
}

public enum ContentType: String, Codable, Sendable {
    case inputText = "input_text"
    case inputAudio = "input_audio"
    case itemReference = "item_reference"
    case text
    case audio
}
