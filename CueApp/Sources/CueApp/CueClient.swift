import Foundation

// MARK: - Models

struct Author: Codable {
    let role: String
}

struct Content: Codable {
    let type: String
    let texts: [String]
}

struct FeatureFlag: Codable {
    let isCli: Bool
    let enableReasoning: Bool
    
    enum CodingKeys: String, CodingKey {
        case isCli = "is_cli"
        case enableReasoning = "enable_reasoning"
    }
    
    init(isCli: Bool = false, enableReasoning: Bool = false) {
        self.isCli = isCli
        self.enableReasoning = enableReasoning
    }
}

struct CompletionRequest: Codable {
    let conversationId: String
    let parentMessageId: String?
    let model: String
    let author: Author
    let content: Content
    let websocketRequestId: String
    let featureFlag: FeatureFlag
    let additionalSystemMessage: String?
    
    enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case parentMessageId = "parent_message_id"
        case model
        case author
        case content
        case websocketRequestId = "websocket_request_id"
        case featureFlag = "feature_flag"
        case additionalSystemMessage = "additional_system_message"
    }
}

struct Message: Codable, Identifiable {
    let id: String
    let conversationId: String
    let parentId: String?
    let childrenIds: [String]
    let author: Author
    let content: Content
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case parentId = "parent_id"
        case childrenIds = "children_ids"
        case author
        case content
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Client

enum CueClientError: Error {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case decodingError(Error)
    case apiError(String)
    case unexpectedResponse(String)
}

@MainActor
final class CueClient {
    private let baseURL: URL
    private let session: URLSession
    private let jsonDecoder: JSONDecoder
    private let jsonEncoder: JSONEncoder
    
    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        
        self.jsonDecoder = JSONDecoder()
        self.jsonDecoder.dateDecodingStrategy = .iso8601
        
        self.jsonEncoder = JSONEncoder()
        self.jsonEncoder.dateEncodingStrategy = .iso8601
        self.jsonEncoder.keyEncodingStrategy = .convertToSnakeCase
    }
    
    /// Sends a message to a conversation and returns the list of messages (usually the user message and the assistant's response)
    /// - Parameters:
    ///   - conversationId: The ID of the conversation
    ///   - text: The message text to send
    ///   - parentMessageId: Optional ID of the parent message
    ///   - model: The AI model to use (e.g. "gpt-4")
    ///   - additionalSystemMessage: Optional system message to include
    /// - Returns: Array of messages including the user's message and the assistant's response
    func sendMessage(
        conversationId: String,
        text: String,
        parentMessageId: String? = nil,
        model: String = "gpt-4",
        additionalSystemMessage: String? = nil
    ) async throws -> [Message] {
        let endpoint = "conversation/\(conversationId)"
        let url = baseURL.appendingPathComponent(endpoint)
        
        let request = CompletionRequest(
            conversationId: conversationId,
            parentMessageId: parentMessageId,
            model: model,
            author: Author(role: "user"),
            content: Content(
                type: "text",
                texts: [text]
            ),
            websocketRequestId: UUID().uuidString,
            featureFlag: FeatureFlag(),
            additionalSystemMessage: additionalSystemMessage
        )
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try jsonEncoder.encode(request)
        
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CueClientError.invalidResponse
            }
            
            if !(200...299).contains(httpResponse.statusCode) {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw CueClientError.apiError(errorMessage)
            }
            
            return try jsonDecoder.decode([Message].self, from: data)
            
        } catch let error as CueClientError {
            throw error
        } catch let error as DecodingError {
            throw CueClientError.decodingError(error)
        } catch {
            throw CueClientError.networkError(error)
        }
    }
    
    /// Saves an assistant message to a conversation
    /// - Parameters:
    ///   - conversationId: The ID of the conversation
    ///   - message: The message to save
    /// - Returns: The saved message
    func saveAssistantMessage(
        conversationId: String,
        message: CompletionRequest
    ) async throws -> Message {
        let endpoint = "conversation/\(conversationId)/save"
        let url = baseURL.appendingPathComponent(endpoint)
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try jsonEncoder.encode(message)
        
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CueClientError.invalidResponse
            }
            
            if !(200...299).contains(httpResponse.statusCode) {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw CueClientError.apiError(errorMessage)
            }
            
            return try jsonDecoder.decode(Message.self, from: data)
            
        } catch let error as CueClientError {
            throw error
        } catch let error as DecodingError {
            throw CueClientError.decodingError(error)
        } catch {
            throw CueClientError.networkError(error)
        }
    }
}