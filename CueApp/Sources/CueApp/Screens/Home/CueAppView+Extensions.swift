import OpenAI

extension Item.Message.Content {
    var id: String {
        switch self {
        case .text(let text), .input_text(let text):
            return "text_\(text.hashValue)"
        case .audio(let audio), .input_audio(let audio):
            return "audio_\(audio.audio.hashValue)"
        }
    }
}
