// LiveAPIWebSocketManager+Types.swift
import Foundation

// MARK: - Request Types

//struct LiveAPISetup: Codable {
//    let setup: SetupConfig
//    
//    struct SetupConfig: Codable {
//        let model: String
//    }
//}

//struct LiveAPIClientContent: Codable {
//    let clientContent: ClientContent
//    
//    struct ClientContent: Codable {
//        let turnComplete: Bool
//        let turns: [Turn]
//        
//        struct Turn: Codable {
//            let role: String
//            let parts: [Part]
//            
//            struct Part: Codable {
//                let text: String?
//            }
//        }
//    }
//}

//struct LiveAPIRealtimeInput: Codable {
//    let realtimeInput: RealtimeInput
//    
//    struct RealtimeInput: Codable {
//        let mediaChunks: [MediaChunk]
//        
//        struct MediaChunk: Codable {
//            let mimeType: String
//            let data: String // base64 encoded data
//            
//            enum CodingKeys: String, CodingKey {
//                case mimeType = "mime_type"
//                case data
//            }
//        }
//    }
//}

//// MARK: - Response Types
//
//struct LiveAPIResponse: Codable {
//    let serverContent: ServerContent?
//    
//    struct ServerContent: Codable {
//        let modelTurn: ModelTurn?
//        let turnComplete: Bool?
//        
//        struct ModelTurn: Codable {
//            let parts: [Part]?
//            
//            struct Part: Codable {
//                let inlineData: InlineData?
//                
//                struct InlineData: Codable {
//                    let data: String // base64 encoded data
//                }
//            }
//        }
//    }
//}

//enum LiveAPIError: Error {
//    case invalidURL
//    case encodingError
//    case decodingError
//    case audioError(message: String)
//    case permissionDenied
//}

//actor AsyncQueue<T> {
//    private var items: [T] = []
//    private let maxSize: Int
//    
//    init(maxSize: Int) {
//        self.maxSize = maxSize
//    }
//    
//    func put(_ item: T) async throws {
//        while items.count >= maxSize {
//            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
//        }
//        items.append(item)
//    }
//    
//    func get() async throws -> T {
//        while items.isEmpty {
//            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
//        }
//        let item = items.removeFirst()
//        return item
//    }
//}

//
//// MARK: - AsyncQueue Class (Assumed Definition)
//@preconcurrency import Foundation
//
//// Make Element conform to Sendable to ensure thread safety
//final class AsyncQueue<Element: Sendable> {
//    private let maxSize: Int
//    private var elements: [Element] = []
//    private let lock = NSLock()
//    
//    init(maxSize: Int) {
//        self.maxSize = maxSize
//    }
//    
//    func put(_ element: Element) async throws {
//        return try await withCheckedThrowingContinuation { continuation in
//            lock.lock()
//            defer { lock.unlock() }
//            
//            if elements.count < maxSize {
//                elements.append(element)
//                continuation.resume()
//            } else {
//                continuation.resume(throwing: QueueError.queueFull)
//            }
//        }
//    }
//    
//    func get() async throws -> Element {
//        return try await withCheckedThrowingContinuation { continuation in
//            lock.lock()
//            defer { lock.unlock() }
//            
//            if !elements.isEmpty {
//                let element = elements.removeFirst()
//                continuation.resume(returning: element)
//            } else {
//                continuation.resume(throwing: QueueError.queueEmpty)
//            }
//        }
//    }
//}
//
//// Custom errors for queue operations
//enum QueueError: Error {
//    case queueFull
//    case queueEmpty
//}
