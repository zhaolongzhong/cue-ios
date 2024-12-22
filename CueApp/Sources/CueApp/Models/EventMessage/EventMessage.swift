import Foundation

// MARK: - EventMessageType

enum EventMessageType: String, Codable {
    case generic = "generic"
    case user = "user"
    case assistant = "assistant"
    case clientConnect = "client_connect"
    case clientDisconnect = "client_disconnect"
    case clientStatus = "client_status"
    case ping = "ping"
    case pong = "pong"
    case error = "error"
}

// MARK: - Metadata

struct Metadata: Codable {
    var author: Author?
    var model: String?

    struct Author: Codable {
        var role: String
        var name: String?
    }
}

// MARK: - MessagePayloadBase

struct MessagePayloadBase: Codable {
    var message: String?
    var sender: String?
    var recipient: String?
    var websocketRequestId: String?
    var metadata: Metadata?
}

// MARK: - GenericMessagePayload

struct GenericMessagePayload: Codable {
    var message: String?
    var sender: String?
    var recipient: String?
    var websocketRequestId: String?
    var metadata: [String: String]?
    var userId: String?
    var msgId: String?
}

// MARK: - MessagePayload

public struct MessagePayload: Codable, Sendable {
    var message: String?
    var sender: String
    var recipient: String?
    var websocketRequestId: String?
    var metadata: Metadata?
    var userId: String
    var msgId: String?
    var payload: JSONValue?
}

extension MessagePayload {
    var recipientAssistantId: String? {
        // Special recipient values
        if recipient == nil || recipient?.isEmpty == true || recipient == "all" {
            if sender != userId {
                return sender // If sender is assistant, return it
            } else {
                return nil // If sender is user, no assistant
            }
        }

        // Normal recipient routing
        if userId != recipient {
            return recipient // Recipient is assistant
        } else if sender != userId {
            return sender // Sender is assistant, recipient is user
        }
        return nil
    }
}

// MARK: - ClientEventPayload

struct ClientEventPayload: Codable {
    var message: String?
    var sender: String?
    var recipient: String?
    var websocketRequestId: String?
    var metadata: Metadata?
    var clientId: String
    var userId: String?
    var msgId: String?
    var payload: JSONValue?
}

// MARK: - PingPongEventPayload

struct PingPongEventPayload: Codable {
    var message: String?
    var sender: String?
    var recipient: String?
    var websocketRequestId: String?
    var metadata: Metadata?
    var type: String
}

// MARK: - EventPayload

enum EventPayload: Codable, Sendable {
    case clientEvent(ClientEventPayload)
    case pingPongEvent(PingPongEventPayload)
    case message(MessagePayload)
    case genericMessage(GenericMessagePayload)

    // Custom initializer to decode based on available keys
    init(from decoder: Decoder) throws {
        // Decoding is handled in EventMessage based on type
        throw DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Cannot decode EventPayload directly")
        )
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .clientEvent(let payload):
            try payload.encode(to: encoder)
        case .pingPongEvent(let payload):
            try payload.encode(to: encoder)
        case .message(let payload):
            try payload.encode(to: encoder)
        case .genericMessage(let payload):
            try payload.encode(to: encoder)
        }
    }
}

// MARK: - EventMessage

public struct EventMessage: Codable, Sendable {
    var type: EventMessageType
    var payload: EventPayload
    var clientId: String?
    var metadata: Metadata?
    var websocketRequestId: String?

    enum CodingKeys: String, CodingKey {
        case type
        case payload
        case clientId = "client_id"
        case metadata
        case websocketRequestId = "websocket_request_id"
    }

    // Memberwise Initializer
    init(
        type: EventMessageType,
        payload: EventPayload,
        clientId: String? = nil,
        metadata: Metadata? = nil,
        websocketRequestId: String? = nil
    ) {
        self.type = type
        self.payload = payload
        self.clientId = clientId
        self.metadata = metadata
        self.websocketRequestId = websocketRequestId
    }

    // Custom Decoder
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(EventMessageType.self, forKey: .type)
        self.clientId = try container.decodeIfPresent(String.self, forKey: .clientId)
        self.metadata = try container.decodeIfPresent(Metadata.self, forKey: .metadata)
        self.websocketRequestId = try container.decodeIfPresent(String.self, forKey: .websocketRequestId)

        switch type {
        case .clientConnect, .clientDisconnect, .clientStatus:
            let clientEventPayload = try container.decode(ClientEventPayload.self, forKey: .payload)
            payload = .clientEvent(clientEventPayload)
        case .ping, .pong:
            let pingPongPayload = try container.decode(PingPongEventPayload.self, forKey: .payload)
            payload = .pingPongEvent(pingPongPayload)
        case .user, .assistant:
            let messagePayload = try container.decode(MessagePayload.self, forKey: .payload)
            payload = .message(messagePayload)
        case .generic, .error:
            let genericPayload = try container.decode(GenericMessagePayload.self, forKey: .payload)
            payload = .genericMessage(genericPayload)
        }
    }

    // Custom Encoder
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)

        switch payload {
        case .clientEvent(let clientEventPayload):
            try container.encode(clientEventPayload, forKey: .payload)
        case .pingPongEvent(let pingPongPayload):
            try container.encode(pingPongPayload, forKey: .payload)
        case .message(let messagePayload):
            try container.encode(messagePayload, forKey: .payload)
        case .genericMessage(let genericPayload):
            try container.encode(genericPayload, forKey: .payload)
        }

        try container.encodeIfPresent(clientId, forKey: .clientId)
        try container.encodeIfPresent(metadata, forKey: .metadata)
        try container.encodeIfPresent(websocketRequestId, forKey: .websocketRequestId)
    }
}
