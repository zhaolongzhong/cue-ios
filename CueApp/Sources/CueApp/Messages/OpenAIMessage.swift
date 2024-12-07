import Foundation
// import CueOpenAI

public struct ToolCall: Codable, Sendable, Equatable {
    public let id: String
    public let type: String
    public let function: Function

    public init(id: String, type: String, function: Function) {
        self.id = id
        self.type = type
        self.function = function
    }

    public static func == (lhs: ToolCall, rhs: ToolCall) -> Bool {
        return lhs.id == rhs.id &&
            lhs.type == rhs.type &&
            lhs.function == rhs.function
    }
}

public struct Function: Codable, Sendable, Equatable {
    public let name: String
    public let arguments: String

    public init(name: String, arguments: String) {
        self.name = name
        self.arguments = arguments
    }

    public static func == (lhs: Function, rhs: Function) -> Bool {
        return lhs.name == rhs.name &&
            lhs.arguments == rhs.arguments
    }
}

// MARK: - Usage Details
public struct Usage: Codable, Sendable {
    public let totalTokens: Int
    public let completionTokens: Int
    public let completionTokensDetails: TokenDetails
    public let promptTokensDetails: PromptTokenDetails
    public let promptTokens: Int

    public init(totalTokens: Int, completionTokens: Int, completionTokensDetails: TokenDetails, promptTokensDetails: PromptTokenDetails, promptTokens: Int) {
        self.totalTokens = totalTokens
        self.completionTokens = completionTokens
        self.completionTokensDetails = completionTokensDetails
        self.promptTokensDetails = promptTokensDetails
        self.promptTokens = promptTokens
    }

    enum CodingKeys: String, CodingKey {
        case totalTokens = "total_tokens"
        case completionTokens = "completion_tokens"
        case completionTokensDetails = "completion_tokens_details"
        case promptTokensDetails = "prompt_tokens_details"
        case promptTokens = "prompt_tokens"
    }
}

public struct TokenDetails: Codable, Sendable {
    public let rejectedPredictionTokens: Int
    public let audioTokens: Int
    public let acceptedPredictionTokens: Int
    public let reasoningTokens: Int

    public init(rejectedPredictionTokens: Int, audioTokens: Int, acceptedPredictionTokens: Int, reasoningTokens: Int) {
        self.rejectedPredictionTokens = rejectedPredictionTokens
        self.audioTokens = audioTokens
        self.acceptedPredictionTokens = acceptedPredictionTokens
        self.reasoningTokens = reasoningTokens
    }

    enum CodingKeys: String, CodingKey {
        case rejectedPredictionTokens = "rejected_prediction_tokens"
        case audioTokens = "audio_tokens"
        case acceptedPredictionTokens = "accepted_prediction_tokens"
        case reasoningTokens = "reasoning_tokens"
    }
}

public struct PromptTokenDetails: Codable, Sendable {
    public let cachedTokens: Int
    public let audioTokens: Int

    public init(cachedTokens: Int, audioTokens: Int) {
        self.cachedTokens = cachedTokens
        self.audioTokens = audioTokens
    }

    enum CodingKeys: String, CodingKey {
        case cachedTokens = "cached_tokens"
        case audioTokens = "audio_tokens"
    }
}

// MARK: - Choice and Message
public struct Choice: Codable, Sendable {
    public let finishReason: String
    public let message: AssistantMessage
    public let index: Int

    public init(finishReason: String, message: AssistantMessage, index: Int) {
        self.finishReason = finishReason
        self.message = message
        self.index = index
    }

    enum CodingKeys: String, CodingKey {
        case finishReason = "finish_reason"
        case message
        case index
    }
}

public struct AssistantMessage: Codable, Sendable {
    public let toolCalls: [ToolCall]
    public let role: String

    public init(toolCalls: [ToolCall], role: String) {
        self.toolCalls = toolCalls
        self.role = role
    }

    enum CodingKeys: String, CodingKey {
        case toolCalls = "tool_calls"
        case role
    }
}

// MARK: - ChatCompletion
public struct ChatCompletion: Codable, Sendable {
    public let systemFingerprint: String
    public let usage: Usage
    public let choices: [Choice]
    public let id: String
    public let object: String
    public let model: String
    public let created: Int

    public init(systemFingerprint: String, usage: Usage, choices: [Choice], id: String, object: String, model: String, created: Int) {
        self.systemFingerprint = systemFingerprint
        self.usage = usage
        self.choices = choices
        self.id = id
        self.object = object
        self.model = model
        self.created = created
    }

    enum CodingKeys: String, CodingKey {
        case systemFingerprint = "system_fingerprint"
        case usage
        case choices
        case id
        case object
        case model
        case created
    }
}

// MARK: - Tool message
public struct ToolMessage: Codable, Sendable {
    public let toolCallId: String
    public let content: String
    public let name: String
    public let role: String

    public init(toolCallId: String, content: String, name: String, role: String) {
        self.toolCallId = toolCallId
        self.content = content
        self.name = name
        self.role = role
    }

    enum CodingKeys: String, CodingKey {
        case toolCallId = "tool_call_id"
        case content
        case name
        case role
    }
}

extension JSONValue {
    func toChatCompletion() -> ChatCompletion? {
        guard case .dictionary(let dict) = self else { return nil }

        // Extract required fields
        guard let id = dict["id"]?.asString,
              let object = dict["object"]?.asString,
              let model = dict["model"]?.asString,
              let systemFingerprint = dict["system_fingerprint"]?.asString,
              case .int(let created) = dict["created"],
              case .array(let choicesArray) = dict["choices"],
              case .dictionary(let usageDict) = dict["usage"] else {
            return nil
        }

        // Parse choices
        let choices: [Choice] = choicesArray.compactMap { choiceValue in
            guard case .dictionary(let choiceDict) = choiceValue,
                  let finishReason = choiceDict["finish_reason"]?.asString,
                  case .int(let index) = choiceDict["index"],
                  case .dictionary(let messageDict) = choiceDict["message"] else {
                return nil
            }

            // Parse message
            let role = messageDict["role"]?.asString ?? "assistant"

            // Parse tool_calls if present
            let toolCalls: [ToolCall] = {
                guard case .array(let toolCallsArray)? = messageDict["tool_calls"] else {
                    return []
                }

                return toolCallsArray.compactMap { toolCallValue in
                    guard case .dictionary(let toolCallDict) = toolCallValue,
                          let id = toolCallDict["id"]?.asString,
                          let type = toolCallDict["type"]?.asString,
                          case .dictionary(let functionDict) = toolCallDict["function"],
                          let name = functionDict["name"]?.asString,
                          let arguments = functionDict["arguments"]?.asString else {
                        return nil
                    }

                    return ToolCall(
                        id: id,
                        type: type,
                        function: Function(name: name, arguments: arguments)
                    )
                }
            }()

            return Choice(
                finishReason: finishReason,
                message: AssistantMessage(toolCalls: toolCalls, role: role),
                index: index
            )
        }

        // Parse usage
        guard case .int(let totalTokens) = usageDict["total_tokens"],
              case .int(let completionTokens) = usageDict["completion_tokens"],
              case .int(let promptTokens) = usageDict["prompt_tokens"],
              case .dictionary(let completionTokensDetailsDict) = usageDict["completion_tokens_details"],
              case .dictionary(let promptTokensDetailsDict) = usageDict["prompt_tokens_details"] else {
            return nil
        }

        // Parse completion tokens details
        guard case .int(let rejectedPredictionTokens) = completionTokensDetailsDict["rejected_prediction_tokens"],
              case .int(let audioTokens) = completionTokensDetailsDict["audio_tokens"],
              case .int(let acceptedPredictionTokens) = completionTokensDetailsDict["accepted_prediction_tokens"],
              case .int(let reasoningTokens) = completionTokensDetailsDict["reasoning_tokens"] else {
            return nil
        }

        let completionTokensDetails = TokenDetails(
            rejectedPredictionTokens: rejectedPredictionTokens,
            audioTokens: audioTokens,
            acceptedPredictionTokens: acceptedPredictionTokens,
            reasoningTokens: reasoningTokens
        )

        // Parse prompt tokens details
        guard case .int(let promptAudioTokens) = promptTokensDetailsDict["audio_tokens"],
              case .int(let cachedTokens) = promptTokensDetailsDict["cached_tokens"] else {
            return nil
        }

        let promptTokensDetails = PromptTokenDetails(
            cachedTokens: cachedTokens,
            audioTokens: promptAudioTokens
        )

        let usage = Usage(
            totalTokens: totalTokens,
            completionTokens: completionTokens,
            completionTokensDetails: completionTokensDetails,
            promptTokensDetails: promptTokensDetails,
            promptTokens: promptTokens
        )

        return ChatCompletion(
            systemFingerprint: systemFingerprint,
            usage: usage,
            choices: choices,
            id: id,
            object: object,
            model: model,
            created: created
        )
    }
}
