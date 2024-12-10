import Foundation
import CueOpenAI

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
        let choices: [Choice] = choicesArray.compactMap { choiceValue -> Choice? in
            guard case .dictionary(let choiceDict) = choiceValue,
                  let finishReason = choiceDict["finish_reason"]?.asString,
                  case .int(let index) = choiceDict["index"],
                  case .dictionary(let messageDict) = choiceDict["message"] else {
                return nil
            }

            // Parse message
            let role = messageDict["role"]?.asString ?? "assistant"
            let content = messageDict["content"]?.asString

            // Parse tool_calls if present
            let toolCalls: [ToolCall]? = {
                guard case .array(let toolCallsArray)? = messageDict["tool_calls"] else {
                    return nil
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
                message: AssistantMessage(role: role, content: content, toolCalls: toolCalls),
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
