//
//  StreamingServerEvent.swift
//  CueOpenAI
//


import Foundation
import CueCommon
import os.log

// MARK: - Server Event

/// Enum representing all possible events from the OpenAI API
public enum ServerStreamingEvent: Identifiable, Sendable {
    /// Raw chunk event received from OpenAI
    case chunk(OpenAI.ChatCompletionChunk)
    /// Error event
    case error(ErrorEvent)
    /// Completed event
    case completed

    // MARK: - Identifiable Conformance

    public var id: String {
        switch self {
        case .chunk(let chunk):
            return chunk.id
        case .error(let event):
            return event.id
        case .completed:
            return UUID().uuidString
        }
    }

    /// Get the event type as a string
    public var type: String {
        switch self {
        case .chunk:
            return "chunk"
        case .error:
            return "error"
        case .completed:
            return "completed"
        }
    }
}

extension ServerStreamingEvent {
    /// Base protocol for all OpenAI events
    public protocol EventProtocol: Identifiable, Sendable {
        var id: String { get }
    }

    // MARK: - Connection State

    /// Represents the state of the connection to OpenAI API
    public enum ConnectionState: Sendable {
        case connecting
        case connected
        case disconnected(Error?)
    }

    /// Event received when an error occurs
    public struct ErrorEvent: EventProtocol, Sendable {
        public let id: String
        public let error: OpenAI.Error

        public init(id: String, error: OpenAI.Error) {
            self.id = id
            self.error = error
        }
    }
}
