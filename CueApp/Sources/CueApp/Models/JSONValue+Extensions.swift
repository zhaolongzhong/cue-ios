import Foundation
import CueCommon
import CueOpenAI
import CueAnthropic

extension JSONValue {
    func toChatCompletion() -> OpenAI.ChatCompletion? {
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
        let choices: [OpenAI.Choice] = choicesArray.compactMap { choiceValue -> OpenAI.Choice? in
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

            return OpenAI.Choice(
                finishReason: finishReason,
                message: OpenAI.AssistantMessage(role: role, content: content, toolCalls: toolCalls),
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

        let completionTokensDetails = OpenAI.TokenDetails(
            rejectedPredictionTokens: rejectedPredictionTokens,
            audioTokens: audioTokens,
            acceptedPredictionTokens: acceptedPredictionTokens,
            reasoningTokens: reasoningTokens
        )

        let cachedTokens = promptTokensDetailsDict["cached_tokens"]?.asInt ?? 0
        let promptTokensDetails = OpenAI.PromptTokenDetails(cachedTokens: cachedTokens)

        let usage = OpenAI.Usage(
            totalTokens: totalTokens,
            completionTokens: completionTokens,
            completionTokensDetails: completionTokensDetails,
            promptTokensDetails: promptTokensDetails,
            promptTokens: promptTokens
        )

        return OpenAI.ChatCompletion(
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

extension JSONValue {
    public func toAnthropicMessage() -> Anthropic.AnthropicMessage? {
        guard case .dictionary(let dict) = self else { return nil }

        // Extract required fields
        guard let id = dict["id"]?.asString,
              let model = dict["model"]?.asString,
              let role = dict["role"]?.asString,
              let type = dict["type"]?.asString,
              let stopReason = dict["stop_reason"]?.asString,
              case .array(let contentArray) = dict["content"] else {
            return nil
        }

        // Parse stop sequence (optional)
        let stopSequence = dict["stop_sequence"]?.asString

        // Parse content items
        let content: [Anthropic.ContentBlock?] = contentArray.map { contentValue -> Anthropic.ContentBlock? in
            guard case .dictionary(let contentDict) = contentValue,
                  let typeStr = contentDict["type"]?.asString else {
                return nil
            }

            // Parse based on content type
            switch typeStr {
            case "text":
                guard let text = contentDict["text"]?.asString else { return nil }
                return Anthropic.ContentBlock(content: text)

            case "tool_use":
                guard let _ = contentDict["id"]?.asString,
                      let name = contentDict["name"]?.asString,
                      case .dictionary(_)? = contentDict["input"] else {
                    return nil
                }
                return Anthropic.ContentBlock(content: "Tool use: \(name)")
            default:
                print("unexpected type")
            }
            return nil
        }

        let usage: Anthropic.Usage?
        if case .dictionary(let usageDict) = dict["usage"] {
            usage = parseAnthropicUsage(from: usageDict)
        } else {
            usage = nil
        }

        guard let usage = usage else { return nil }

        return Anthropic.AnthropicMessage(
            id: id,
            content: content.compactMap { $0},
            model: model,
            role: role,
            stopReason: stopReason,
            stopSequence: stopSequence,
            type: type,
            usage: usage
        )
    }

    private func parseAnthropicUsage(from dict: [String: JSONValue]) -> Anthropic.Usage? {
        return Anthropic.Usage(
            cacheCreationInputTokens: dict["cache_creation_input_tokens"]?.asInt,
            cacheReadInputTokens: dict["cache_read_input_tokens"]?.asInt,
            inputTokens: dict["input_tokens"]?.asInt,
            outputTokens: dict["output_tokens"]?.asInt
        )
    }
}
