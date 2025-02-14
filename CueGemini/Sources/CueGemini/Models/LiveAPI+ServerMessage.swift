import Foundation
import OSLog

private let logger = Logger(subsystem: "LiveAPI", category: "ServerMessage")

public enum ServerMessage: Decodable, Sendable {
    case setupComplete(BidiGenerateContentSetupComplete)
    case serverContent(BidiGenerateContentServerContent)
    case toolCall(BidiGenerateContentToolCall)
    case toolCallCancellation(BidiGenerateContentToolCallCancellation)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let setupComplete = try container.decodeIfPresent(BidiGenerateContentSetupComplete.self, forKey: .setupComplete) {
            self = .setupComplete(setupComplete)
        } else if let serverContent = try container.decodeIfPresent(BidiGenerateContentServerContent.self, forKey: .serverContent) {
            self = .serverContent(serverContent)
        } else if let toolCall = try container.decodeIfPresent(BidiGenerateContentToolCall.self, forKey: .toolCall) {
            self = .toolCall(toolCall)
        } else if let cancellation = try container.decodeIfPresent(BidiGenerateContentToolCallCancellation.self, forKey: .toolCallCancellation) {
            self = .toolCallCancellation(cancellation)
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .setupComplete,
                in: container,
                debugDescription: "Server message must contain exactly one of: setupComplete, serverContent, toolCall, or toolCallCancellation"
            )
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case setupComplete = "setupComplete"
        case serverContent = "serverContent"
        case toolCall = "toolCall"
        case toolCallCancellation = "toolCallCancellation"
    }
}

public struct BidiGenerateContentSetupComplete: Decodable, Sendable {}

public struct BidiGenerateContentServerContent: Decodable, Sendable {
    public let turnComplete: Bool
    public let interrupted: Bool
    public let modelTurn: ModelContent

    public init(turnComplete: Bool = false, interrupted: Bool = false, modelTurn: ModelContent) {
        self.modelTurn = modelTurn
        self.turnComplete = turnComplete
        self.interrupted = interrupted
    }

    enum CodingKeys: String, CodingKey {
        case turnComplete = "turnComplete"
        case interrupted = "interrupted"
        case modelTurn = "modelTurn"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode optional fields with defaults and log
        self.turnComplete = try {
            let value = try container.decodeIfPresent(Bool.self, forKey: .turnComplete) ?? false
            return value
        }()

        self.interrupted = try {
            let value = try container.decodeIfPresent(Bool.self, forKey: .interrupted) ?? false
            return value
        }()

        do {
            if let content = try container.decodeIfPresent(ModelContent.self, forKey: .modelTurn) {
                self.modelTurn = content
            } else {
                logger.debug("No modelTurn found, creating empty ModelContent")
                self.modelTurn = ModelContent(parts: [])
            }
        } catch {
            logger.error("Error decoding modelTurn: \(error)")
            if let emptyDict = try? container.decode([String: String].self, forKey: .modelTurn),
               emptyDict.isEmpty {
                logger.debug("Found empty dictionary for modelTurn")
                throw InvalidCandidateError.emptyContent(underlyingError: error)
            }

            logger.debug("Throwing malformed content error")
            throw InvalidCandidateError.malformedContent(underlyingError: error)
        }
    }
}

public struct BidiGenerateContentToolCall: Decodable, Sendable {
    public let functionCalls: [FunctionCall]?

    enum CodingKeys: String, CodingKey {
        // https://github.com/google-gemini/cookbook/blob/main/gemini-2/websockets/live_api_tool_use.ipynb
        // https://ai.google.dev/gemini-api/docs/multimodal-live#bidigeneratecontenttoolcall
        case functionCalls = "functionCalls"
    }
}

public struct BidiGenerateContentToolCallCancellation: Decodable, Sendable {
    public let ids: [String]?

    enum CodingKeys: String, CodingKey {
        case ids
    }
}
