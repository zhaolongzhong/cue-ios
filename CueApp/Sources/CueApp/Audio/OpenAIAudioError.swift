import Foundation
import AVFAudio

public enum OpenAIAudioError: LocalizedError {
    case permissionDenied
    case audioSessionSetupFailed(Error)
    case audioEngineSetupFailed(Error)
    case invalidAudioFormat
    case recordingInProgress
    case notRecording
    case bufferCreationFailed
    
    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone access permission denied"
        case .audioSessionSetupFailed(let error):
            return "Failed to setup audio session: \(error.localizedDescription)"
        case .audioEngineSetupFailed(let error):
            return "Failed to setup audio engine: \(error.localizedDescription)"
        case .invalidAudioFormat:
            return "Invalid audio format configuration"
        case .recordingInProgress:
            return "Audio recording already in progress"
        case .notRecording:
            return "Audio recording not in progress"
        case .bufferCreationFailed:
            return "Failed to create audio buffer"
        }
    }
}