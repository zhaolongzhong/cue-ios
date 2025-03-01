//
//  MessageContent+Extensions.swift
//  CueApp
//

import Foundation
import CueCommon
import CueAnthropic
import CueOpenAI

extension MessageContent {
    public var text: String {
        return content.getText()
    }

    public var toolCalls: [ToolCall]? {
        if self.type == .toolCall {
            if case .array(let array) = content {
                return try? JSONDecoder().decode([ToolCall].self, from: JSONEncoder().encode(array))
            }
        }
        return nil
    }

    public var toolUses: [Anthropic.ToolUseBlock]? {
        if self.type == .toolUse {
            if case .array(let array) = content {
                return try? JSONDecoder().decode([Anthropic.ToolUseBlock].self, from: JSONEncoder().encode(array))
            }
        }
        return nil
    }

    public var toolName: String? {
        if let toolCalls = toolCalls {
            return toolCalls.map { $0.function.name }.joined(separator: ", ")
        } else if let toolUses = toolUses {
            return toolUses.map { String(describing: $0.name) }.joined(separator: ", ")
        }
        return nil
    }

    public var toolArgs: String? {
        // For toolCalls
        if let toolCalls = self.toolCalls {
            return toolCalls.map { toolCall -> String in
                // Using prettyArguments for better formatting
                return "\(toolCall.function.name): \(toolCall.function.prettyArguments)"
            }.joined(separator: "; ")
        }

        // For toolUses
        if let toolUses = self.toolUses {
            return toolUses.map { toolUse -> String in
                let inputStr = toolUse.input.map { key, value in
                    "\(key): \(value.asString ?? String(describing: value))"
                }.joined(separator: ", ")
                return "\(toolUse.name): \(inputStr)"
            }.joined(separator: "; ")
        }

        // Manual parsing of content array if needed
        if case .array(let array) = self.content {
            var results: [String] = []

            // Check for tool_use blocks
            let toolUseItems = array.filter { item in
                if case .object(let dict) = item, dict["type"]?.asString == "tool_use" {
                    return true
                }
                return false
            }

            if !toolUseItems.isEmpty {
                for item in toolUseItems {
                    if case .object(let dict) = item,
                       let name = dict["name"]?.asString,
                       case .object(let inputDict) = dict["input"] {
                        let inputStr = inputDict.map { key, value in
                            "\(key): \(value.asString ?? String(describing: value))"
                        }.joined(separator: ", ")
                        results.append("\(name): \(inputStr)")
                    }
                }
            }

            // Check for function_call blocks
            let toolCallItems = array.filter { item in
                if case .object(let dict) = item,
                dict["type"]?.asString == "function" || dict["type"]?.asString == "tool_call" {
                    return true
                }
                return false
            }

            if !toolCallItems.isEmpty {
                for item in toolCallItems {
                    if case .object(let dict) = item,
                       let function = dict["function"],
                       case .object(let functionDict) = function,
                       let name = functionDict["name"]?.asString,
                       let args = functionDict["arguments"]?.asString {
                        // Try to format arguments as pretty JSON
                        let prettyArgs = JSONFormatter.prettyString(from: args) ?? args
                        results.append("\(name): \(prettyArgs)")
                    }
                }
            }

            // Check for tool_result blocks
            let toolResultItems = array.filter { item in
                if case .object(let dict) = item, dict["type"]?.asString == "tool_result" {
                    return true
                }
                return false
            }

            if !toolResultItems.isEmpty {
                for item in toolResultItems {
                    if case .object(let dict) = item,
                       let name = dict["name"]?.asString,
                       let content = dict["content"]?.asString {
                        results.append("\(name): \(content)")
                    }
                }
            }

            if !results.isEmpty {
                return results.joined(separator: "; ")
            }
        }

        return nil
    }
}

extension ContentDetail {
    init(string: String) {
        if let data = string.data(using: .utf8),
           let jsonValue = try? JSONDecoder().decode(JSONValue.self, from: data) {
            switch jsonValue {
            case .array(let array):
                self = .array(array)
            case .object(let dict):
                self = .object(dict)
            default:
                // If it's not a valid JSON array or dictionary, treat as plain string
                self = .string(string)
            }
        } else {
            self = .string(string)
        }
    }

    static func fromString(_ string: String) -> ContentDetail {
        return ContentDetail(string: string)
    }
    static func fromContentValue(_ contentValue: OpenAI.ContentValue) -> ContentDetail {
        switch contentValue {
        case .string(let text):
            return .string(text)
        case .array(let items):
            return .array(items.toJSONValues())
        }
    }

    func getText() -> String {
        switch self {
        case .string(let text):
            return text
        case .array(let array):
            let texts = array
                .compactMap { value -> String? in
                    switch value {
                    case .string(let str):
                        return str
                    case .object(let dict):
                        if let text = dict["text"]?.asString ?? dict["content"]?.asString {
                            return text
                        }
                        return nil
                    default:
                        return nil
                    }
                }
            return texts.reduce("") { result, text in
                result.isEmpty ? text : result + "\n" + text
            }
        case .object(let dict):
            if let text = dict["text"]?.asString ?? dict["content"]?.asString {
                return text
            }
            return ""
        }
    }
}

extension Array where Element == OpenAI.ContentBlock {
    func toJSONValues() -> [JSONValue] {
        return self.map { contentBlock in
            var jsonObject: [String: JSONValue] = [:]
            jsonObject["type"] = .string(contentBlock.type.rawValue)
            switch contentBlock {
            case .text(let text):
                jsonObject["text"] = .string(text)
            case .imageUrl(let image):
                jsonObject["image_url"] = .object(["url": .string(image.url)])
            }
            return .object(jsonObject)
        }
    }
}
