import Foundation
import SwiftUI

extension SyntaxHighlighter {
    static func highlightMarkdown(_ attributedString: NSMutableAttributedString, syntaxColors: [String: Color]) {
        // Remove outer markdown fences.
        removeOuterMarkdownFences(from: attributedString)
        let text = attributedString.string

        // Define patterns and associated syntax keys.
        let patterns: [(pattern: String, options: NSRegularExpression.Options, key: String)] = [
            ("```([\\s\\S]*?)```", [], "nested-code"),
            ("^(#{1,6})\\s+(.+)$", [.anchorsMatchLines], "header"),
            ("^>\\s+(.+)$", [.anchorsMatchLines], "blockquote"),
            ("^\\s*\\d+\\.\\s+(.+)$", [.anchorsMatchLines], "orderedlist"),
            ("^\\s*[-\\*\\+]\\s+(.+)$", [.anchorsMatchLines], "list")
        ]

        // Process each pattern.
        for item in patterns {
            applyHighlighting(
                pattern: item.pattern,
                options: item.options,
                colorKey: item.key,
                syntaxColors: syntaxColors,
                attributedString: attributedString,
                text: text
            )
        }
    }

    private static func removeOuterMarkdownFences(from attributedString: NSMutableAttributedString) {
        let text = attributedString.string
        var lines = text.components(separatedBy: "\n")
        if lines.count >= 2,
           let firstLine = lines.first, firstLine.hasPrefix("```"),
           let lastLine = lines.last, lastLine.trimmingCharacters(in: .whitespaces) == "```" {
            lines.removeFirst()
            lines.removeLast()
            let newText = lines.joined(separator: "\n")
            attributedString.mutableString.setString(newText)
        }
    }

    private static func applyHighlighting(pattern: String,
                                          options: NSRegularExpression.Options,
                                          colorKey: String,
                                          syntaxColors: [String: Color],
                                          attributedString: NSMutableAttributedString,
                                          text: String) {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: options)
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: attributedString.length))
            for match in matches.reversed() {
                if !isInsideCodeBlock(match.range, text: text) {
                    attributedString.addAttribute(
                        .foregroundColor,
                        value: colorToNative(syntaxColors[colorKey]!),
                        range: match.range
                    )
                }
            }
        } catch {
            log.error("\(colorKey.capitalized) regex error: \(error)")
        }
    }

    private static func isInsideCodeBlock(_ range: NSRange, text: String) -> Bool {
        let codeBlockPattern = "```[\\s\\S]*?```"
        do {
            let regex = try NSRegularExpression(pattern: codeBlockPattern, options: [])
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: text.count))
            for match in matches {
                if match.range.location <= range.location &&
                   match.range.location + match.range.length >= range.location + range.length {
                    return true
                }
            }
        } catch {
            log.error("Code block check error: \(error)")
        }
        return false
    }
}
