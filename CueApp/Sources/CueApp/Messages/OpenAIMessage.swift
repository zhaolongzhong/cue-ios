import Foundation

struct ToolCall: Codable, Sendable, Equatable {
    let id: String
    let type: String
    let function: Function

    static func == (lhs: ToolCall, rhs: ToolCall) -> Bool {
        return lhs.id == rhs.id &&
            lhs.type == rhs.type &&
            lhs.function == rhs.function
    }
}

struct Function: Codable, Sendable, Equatable {
    let name: String
    let arguments: String

    static func == (lhs: Function, rhs: Function) -> Bool {
        return lhs.name == rhs.name &&
            lhs.arguments == rhs.arguments
    }
}

// MARK: - Usage Details
struct Usage: Codable {
    let totalTokens: Int
    let completionTokens: Int
    let completionTokensDetails: TokenDetails
    let promptTokensDetails: PromptTokenDetails
    let promptTokens: Int

    enum CodingKeys: String, CodingKey {
        case totalTokens = "total_tokens"
        case completionTokens = "completion_tokens"
        case completionTokensDetails = "completion_tokens_details"
        case promptTokensDetails = "prompt_tokens_details"
        case promptTokens = "prompt_tokens"
    }
}

struct TokenDetails: Codable {
    let rejectedPredictionTokens: Int
    let audioTokens: Int
    let acceptedPredictionTokens: Int
    let reasoningTokens: Int

    enum CodingKeys: String, CodingKey {
        case rejectedPredictionTokens = "rejected_prediction_tokens"
        case audioTokens = "audio_tokens"
        case acceptedPredictionTokens = "accepted_prediction_tokens"
        case reasoningTokens = "reasoning_tokens"
    }
}

struct PromptTokenDetails: Codable {
    let cachedTokens: Int
    let audioTokens: Int

    enum CodingKeys: String, CodingKey {
        case cachedTokens = "cached_tokens"
        case audioTokens = "audio_tokens"
    }
}

// MARK: - Choice and Message
struct Choice: Codable {
    let finishReason: String
    let message: AssistantMessage
    let index: Int

    enum CodingKeys: String, CodingKey {
        case finishReason = "finish_reason"
        case message
        case index
    }
}

struct AssistantMessage: Codable {
    let toolCalls: [ToolCall]
    let role: String

    enum CodingKeys: String, CodingKey {
        case toolCalls = "tool_calls"
        case role
    }
}

// MARK: - ChatCompletion
struct ChatCompletion: Codable {
    let systemFingerprint: String
    let usage: Usage
    let choices: [Choice]
    let id: String
    let object: String
    let model: String
    let created: Int

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
struct ToolMessage: Codable {
    let toolCallId: String
    let content: String
    let name: String
    let role: String

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