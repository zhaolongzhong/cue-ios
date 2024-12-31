import Foundation
import os.log

public protocol MessageProcessorProtocol: Sendable {
    func encodeEvent<T: Encodable>(_ event: T) throws -> String
    func decodeEvent<T: Decodable>(_ data: Data) throws -> T
}

public final class RealtimeMessageProcessor: MessageProcessorProtocol, Sendable {
    
    private let logger = Logger(subsystem: "RealtimeMessageProcessor",
                        category: "RealtimeMessageProcessor")
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    public init(keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy = .convertToSnakeCase, keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy = .convertFromSnakeCase) {
        encoder = JSONEncoder()
        encoder.keyEncodingStrategy = keyEncodingStrategy
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = keyDecodingStrategy
    }
    
    public func encodeEvent<T: Encodable>(_ event: T) throws -> String {
        let data = try encoder.encode(event)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw RealtimeClientError.encodingError
        }
        return jsonString
    }
    
    public func decodeEvent<T>(_ data: Data) throws -> T where T : Decodable {
        do {
            let serverEvent = try decoder.decode(ServerEvent.self, from: data)
            return serverEvent as! T
        } catch let decodingError as DecodingError {
            logDecodingError(decodingError, data: data)
            throw RealtimeClientError.decodingError
        } catch {
            throw error
        }
    }
    
    
    func logDecodingError(_ error: DecodingError, data: Data, rawText: String? = nil) {
        if let jsonObject = try? JSONSerialization.jsonObject(with: data),
           let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted),
           let prettyJson = String(data: prettyData, encoding: .utf8) {
            logger.debug("📥 Received WebSocket message:\n\(prettyJson)")
        }
        
        switch error {
        case .keyNotFound(let key, let context):
            logger.error("Missing key '\(key.stringValue)' at \(context.codingPath):  \(context.debugDescription)")
        case .valueNotFound(let type, let context):
            logger.error("Missing value for type '\(type)' at \(context.codingPath): \(context.debugDescription)")
        case .typeMismatch(let type, let context):
            logger.error("Type mismatch for type '\(type)' at \(context.codingPath): \(context.debugDescription)")
        case .dataCorrupted(let context):
            logger.error("Data corrupted at \(context.codingPath): \(context.debugDescription)")
        @unknown default:
            logger.error("Unknown decoding error: \(error)")
        }
        
        if let rawText = rawText {   
            logger.error("Raw message text: \(rawText)")
        }
    }
}
