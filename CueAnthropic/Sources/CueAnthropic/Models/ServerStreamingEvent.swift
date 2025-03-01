//
//  ServerEvent.swift
//  CueAnthropic
//

import Foundation
import Combine
import os.log

// MARK: - Server Event

/// Comprehensive enum representing all possible events from the Anthropic API
public enum ServerStreamingEvent: Decodable, Identifiable, Sendable {
    case messageStart(MessageStartEvent)
    case contentBlockStart(ContentBlockStartEvent)
    case contentBlockDelta(ContentBlockDeltaEvent)
    case contentBlockStop(ContentBlockStopEvent)
    case messageDelta(MessageDeltaEvent)
    case messageStop(MessageStopEvent)
    case ping(PingEvent)
    case error(ErrorEvent)

    // MARK: - Identifiable Conformance

    public var id: String {
        switch self {
        case .messageStart(let event):
            return event.id
        case .contentBlockStart(let event):
            return event.id
        case .contentBlockDelta(let event):
            return event.id
        case .contentBlockStop(let event):
            return event.id
        case .messageDelta(let event):
            return event.id
        case .messageStop(let event):
            return event.id
        case .ping(let event):
            return event.id
        case .error(let event):
            return event.id
        }
    }

    public var type: String {
        switch self {
        case .messageStart:
            return "message_start"
        case .contentBlockStart:
            return "content_block_start"
        case .contentBlockDelta:
            return "content_block_delta"
        case .contentBlockStop:
            return "content_block_stop"
        case .messageDelta:
            return "message_delta"
        case .messageStop:
            return "message_stop"
        case .ping:
            return "ping"
        case .error:
            return "error"
        }
    }

    enum CodingKeys: String, CodingKey {
        case type
    }

    enum EventType: String, Codable {
        case messageStart = "message_start"
        case contentBlockStart = "content_block_start"
        case contentBlockDelta = "content_block_delta"
        case contentBlockStop = "content_block_stop"
        case messageDelta = "message_delta"
        case messageStop = "message_stop"
        case ping = "ping"
        case error = "error"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let eventType = try container.decode(String.self, forKey: .type)

        switch eventType {
        case "message_start":
            self = try .messageStart(MessageStartEvent(from: decoder))
        case "content_block_start":
            self = try .contentBlockStart(ContentBlockStartEvent(from: decoder))
        case "content_block_delta":
            self = try .contentBlockDelta(ContentBlockDeltaEvent(from: decoder))
        case "content_block_stop":
            self = try .contentBlockStop(ContentBlockStopEvent(from: decoder))
        case "message_delta":
            self = try .messageDelta(MessageDeltaEvent(from: decoder))
        case "message_stop":
            self = try .messageStop(MessageStopEvent(from: decoder))
        case "ping":
            self = try .ping(PingEvent(from: decoder))
        case "error":
            self = try .error(ErrorEvent(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown event type: \(eventType)")
        }
    }
}
extension ServerStreamingEvent {
    /// Base protocol for all Anthropic events
    public protocol EventProtocol: Decodable, Identifiable {
        var id: String { get }
    }

    // MARK: - Connection State

    /// Represents the state of the connection to Anthropic API
    public enum ConnectionState: Sendable {
        case connecting
        case connected
        case disconnected(Error?)
    }
}
