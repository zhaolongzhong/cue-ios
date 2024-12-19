import Foundation

/// Represents the connection state of the OpenAI Realtime service
enum ConnectionState {
    /// Not connected to OpenAI Realtime service
    case disconnected
    
    /// Connected and ready to process audio
    case connected
    
    /// Actively processing speech
    case processing
}

/// Errors that can occur during OpenAI Realtime operations
enum OpenAIRealtimeError: LocalizedError {
    /// Configuration or initialization error
    case invalidConfiguration
    
    /// Audio recording setup error
    case audioSetupFailed(Error)
    
    /// Network or WebSocket error
    case networkError(Error)
    
    /// Server-side error from OpenAI
    case serverError(String)
    
    /// Audio conversion error
    case audioConversionFailed(Error)
    
    /// Permission error (e.g. microphone access denied)
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "Invalid service configuration"
        case .audioSetupFailed(let error):
            return "Audio setup failed: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .audioConversionFailed(let error):
            return "Audio conversion failed: \(error.localizedDescription)"
        case .permissionDenied:
            return "Microphone access denied"
        }
    }
}

/// Configuration options for OpenAI Realtime service
struct OpenAIRealtimeConfig {
    /// The OpenAI API key
    let apiKey: String
    
    /// The model to use for transcription (default: whisper-1)
    let model: String
    
    /// The language code for transcription (default: en-US) 
    let languageCode: String
    
    /// Silence duration in milliseconds to mark end of speech (default: 700ms)
    let silenceThresholdMs: Int
    
    /// Minimum duration in milliseconds to consider as speech (default: 200ms)
    let speechThresholdMs: Int
    
    /// Audio sample rate in Hz (default: 16000)
    let sampleRate: Int
    
    /// Whether to enable interim results (default: true)
    let enableInterimResults: Bool
    
    /// Maximum duration in seconds for a single transcription (default: 30)
    let maxDurationSec: Int
    
    /// Creates a new configuration with default values
    init(apiKey: String,
         model: String = "whisper-1",
         languageCode: String = "en-US",
         silenceThresholdMs: Int = 700,
         speechThresholdMs: Int = 200,
         sampleRate: Int = 16000,
         enableInterimResults: Bool = true,
         maxDurationSec: Int = 30) {
        self.apiKey = apiKey
        self.model = model
        self.languageCode = languageCode
        self.silenceThresholdMs = silenceThresholdMs
        self.speechThresholdMs = speechThresholdMs
        self.sampleRate = sampleRate
        self.enableInterimResults = enableInterimResults
        self.maxDurationSec = maxDurationSec
    }
}

/// Result type for transcriptions
struct TranscriptionResult {
    /// The transcribed text
    let text: String
    
    /// Whether this is an interim result that may be updated
    let isInterim: Bool
    
    /// Confidence score between 0 and 1 (if available)
    let confidence: Float?
    
    /// Timestamp in seconds from the start of the audio
    let timestamp: TimeInterval?
}

/// Protocol for receiving transcription results and status updates
protocol OpenAIRealtimeDelegate: AnyObject {
    /// Called when transcription is received
    /// - Parameter result: The transcription result containing text and metadata
    func didReceiveTranscription(_ result: TranscriptionResult)
    
    /// Called when speech is detected
    func speechDetected()
    
    /// Called when speech has ended
    func speechEnded()
    
    /// Called when an error occurs
    /// - Parameter error: The error that occurred
    func didEncounterError(_ error: Error)
    
    /// Called when connection state changes
    /// - Parameter state: The new connection state
    func connectionStateDidChange(_ state: ConnectionState)
    
    /// Called when audio levels change (useful for UI feedback)
    /// - Parameter level: Audio level between 0 and 1
    func audioLevelDidChange(_ level: Float)
}

// Default implementations
extension OpenAIRealtimeDelegate {
    func speechDetected() {}
    func speechEnded() {}
    func connectionStateDidChange(_ state: ConnectionState) {}
    func audioLevelDidChange(_ level: Float) {}
}