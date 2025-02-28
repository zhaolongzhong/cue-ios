//
//  OpenAI+ChatCompletionChunk.swift
//  CueOpenAI
//

import CueCommon

extension OpenAI {
    public struct ChatCompletionChunk: Codable, Sendable {
        public let id: String
        public let object: String
        public let created: Int
        public let model: String
        public let systemFingerprint: String?
        public let choices: [ChunkChoice]
        public let usage: Usage?

        enum CodingKeys: String, CodingKey {
            case id
            case object
            case created
            case model
            case systemFingerprint = "system_fingerprint"
            case choices
            case usage
        }
    }

    // Delta content in the response
    public struct ChunkChoice: Codable, Sendable {
        public let index: Int
        public let delta: DeltaContent
        public let logprobs: JSONValue?
        public let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case index
            case delta
            case logprobs
            case finishReason = "finish_reason"
        }
    }

    // Delta content can contain different fields
    public struct DeltaContent: Codable, Sendable {
        public let role: String?
        public let content: String?
        public let toolCalls: [ToolCallDelta]?

        public init(role: String?, content: String? = nil, toolCalls: [ToolCallDelta]? = nil) {
            self.role = role
            self.content = content
            self.toolCalls = toolCalls
        }

        enum CodingKeys: String, CodingKey {
            case role
            case content
            case toolCalls = "tool_calls"
        }
    }

    // Tool call in the streaming response
    public struct ToolCallDelta: Codable, Sendable {
        public let index: Int
        public let id: String?
        public let type: String?
        public let function: FunctionDelta?
    }

    // Function details for tool calls
    public struct FunctionDelta: Codable, Sendable {
        public let name: String?
        public let arguments: String?
    }
}
