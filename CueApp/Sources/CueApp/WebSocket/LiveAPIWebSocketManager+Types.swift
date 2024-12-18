// LiveAPIWebSocketManager+Types.swift
import Foundation

/// MARK: - Encodable Structs for Setup Message

struct LiveAPISetup: Encodable {
    let setup: SetupDetails
}

struct SetupDetails: Encodable {
    let model: String
}

struct LiveAPITool: Encodable {
    // Define tool properties as per API requirements
    // Example:
    // let name: String
    // let description: String
}

// MARK: - Decodable Structs for Responses

struct LiveAPIResponse: Decodable {
    let serverContent: ServerContent?
    let setupComplete: SetupComplete?
    
    enum CodingKeys: String, CodingKey {
        case serverContent = "serverContent"
        case setupComplete = "setupComplete"
    }
}

struct SetupComplete: Decodable {
    // Add fields if there are any. Currently, it's an empty object.
}

struct ServerContent: Decodable {
    let modelTurn: ModelTurn?
    
    enum CodingKeys: String, CodingKey {
        case modelTurn = "modelTurn"
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

// MARK: - LiveAPIRealtimeInput Struct (Assumed Definition)

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

// MARK: - LiveAPIError Enum

enum LiveAPIError: Error {
    case invalidURL
    case encodingError
    case audioError(message: String)
}


// MARK: - AsyncQueue Class

// Make Element conform to Sendable to ensure thread safety
final class AsyncQueue<Element: Sendable> {
    private let maxSize: Int
    private var elements: [Element] = []
    private let lock = NSLock()
    
    init(maxSize: Int) {
        self.maxSize = maxSize
    }
    
    func put(_ element: Element) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            defer { lock.unlock() }
            
            if elements.count < maxSize {
                elements.append(element)
                continuation.resume()
            } else {
                continuation.resume(throwing: QueueError.queueFull)
            }
        }
    }
    
    func get() async throws -> Element {
        return try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            defer { lock.unlock() }
            
            if !elements.isEmpty {
                let element = elements.removeFirst()
                continuation.resume(returning: element)
            } else {
                continuation.resume(throwing: QueueError.queueEmpty)
            }
        }
    }
}

// Custom errors for queue operations
enum QueueError: Error {
    case queueFull
    case queueEmpty
}
