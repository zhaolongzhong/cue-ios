import Foundation
import CueCommon

extension JSONFormatter {
    static func prettyToolResult(_ content: String) -> String {
        let processed = processJSONString(content)

        if let jsonData = processed.data(using: .utf8),
           let jsonArray = try? JSONSerialization.jsonObject(with: jsonData) as? [Any] {
            return prettyString(from: jsonArray) ?? content
        }

        if let jsonData = processed.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) {
            return prettyString(from: jsonObject) ?? content
        }
        return content
    }

    private struct StringProcessor {
        private var result = ""
        private var state: State = .none
        private var escape = false

        private enum State {
            case none, inDouble, inSingle
        }

        // Process a single character based on current state
        mutating func processChar(_ char: Character) {
            switch state {
            case .none:
                processNoneState(char)
            case .inDouble:
                processDoubleQuoteState(char)
            case .inSingle:
                processSingleQuoteState(char)
            }
        }

        // Process character when not in any quote
        private mutating func processNoneState(_ char: Character) {
            switch char {
            case "\"":
                result.append(char)
                state = .inDouble
            case "'":
                result.append("\"")
                state = .inSingle
            default:
                result.append(char)
            }
        }

        // Process character when in double quotes
        private mutating func processDoubleQuoteState(_ char: Character) {
            if escape {
                result.append(char)
                escape = false
                return
            }

            switch char {
            case "\\":
                result.append(char)
                escape = true
            case "\"":
                result.append(char)
                state = .none
            default:
                result.append(char)
            }
        }

        // Process character when in single quotes
        private mutating func processSingleQuoteState(_ char: Character) {
            if escape {
                processSingleQuoteEscape(char)
                return
            }

            switch char {
            case "\\":
                escape = true
            case "'":
                result.append("\"")
                state = .none
            case "\"":
                result.append("\\\"")
            default:
                result.append(char)
            }
        }

        // Handle escaped characters in single quotes
        private mutating func processSingleQuoteEscape(_ char: Character) {
            switch char {
            case "'":
                result.append("'")
            case "\"":
                result.append("\\\"")
            default:
                result.append("\\")
                result.append(char)
            }
            escape = false
        }

        mutating func finalize() -> String {
            if state == .inSingle {
                result.append("\"")
            }
            return result
        }
    }

    static func processJSONString(_ input: String) -> String {
        var processor = StringProcessor()

        for char in input {
            processor.processChar(char)
        }

        return processor.finalize()
    }
}
