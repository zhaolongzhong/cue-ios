import SwiftUI

public struct SyntaxHighlighter {
    public static func syntaxColors(_ colorScheme: ColorScheme) -> [String: Color] {
        if colorScheme == .light {
            return [
                "default": Color.black,
                "keyword": Color(red: 0.607, green: 0.156, blue: 0.560),
                "string": Color(red: 0.800, green: 0.063, blue: 0.063),
                "comment": Color(red: 0.000, green: 0.456, blue: 0.000),
                "number": Color.black,
                "type": Color.black,
                "function": Color.black,
                "property": Color.black
            ]
        } else {
            return [
                "default": Color(red: 0.85, green: 0.85, blue: 0.85), // Slightly Grayish White
                "keyword": Color(red: 0.776, green: 0.472, blue: 0.768),
                "string": Color(red: 0.56, green: 0.93, blue: 0.56), // Light Green
                "comment": Color(red: 0.6, green: 0.6, blue: 0.6),
                "number": Color(red: 0.85, green: 0.85, blue: 0.85),
                "type": Color(red: 0.85, green: 0.85, blue: 0.85),
                "function": Color(red: 0.85, green: 0.85, blue: 0.85),
                "property": Color(red: 0.85, green: 0.85, blue: 0.85)
            ]
        }
    }

    private static func highlight(pattern: String, in attributedString: NSMutableAttributedString, with color: Color) {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
            let range = NSRange(location: 0, length: attributedString.length)
            let matches = regex.matches(in: attributedString.string, range: range)

            for match in matches {
                // For patterns with capture groups, highlight the specific group
                if match.numberOfRanges > 1 {
                    for rangeIndex in 1..<match.numberOfRanges {
                        let matchRange = match.range(at: rangeIndex)
                        attributedString.addAttribute(
                            .foregroundColor,
                            value: colorToNative(color),
                            range: matchRange
                        )
                    }
                } else {
                    attributedString.addAttribute(
                        .foregroundColor,
                        value: colorToNative(color),
                        range: match.range
                    )
                }
            }
        } catch {
            print("Regex error: \(error)")
        }
    }

    public static func highlightedCode(colorScheme: ColorScheme, language: String, code: String) -> NSAttributedString {
        let syntaxColors = syntaxColors(colorScheme)
        let attributedString = NSMutableAttributedString(string: code)

        // Set default color first
        attributedString.addAttribute(
            .foregroundColor,
            value: colorToNative(syntaxColors["default"]!),
            range: NSRange(location: 0, length: attributedString.length)
        )

        // Get language definition
        let languageDef = LanguageDefinitions.getDefinition(for: language)

        // Comments (process first to prevent keyword highlighting inside comments)
        if !languageDef.commentPattern.isEmpty {
            highlight(pattern: languageDef.commentPattern, in: attributedString, with: syntaxColors["comment"]!)
        }

        // Keywords
        if !languageDef.keywords.isEmpty {
            let keywordPattern = "\\b(" + languageDef.keywords.joined(separator: "|") + ")\\b"
            highlight(pattern: keywordPattern, in: attributedString, with: syntaxColors["keyword"]!)
        }

        // String literals
        if !languageDef.stringPattern.isEmpty {
            highlight(pattern: languageDef.stringPattern, in: attributedString, with: syntaxColors["string"]!)
        }

        // Function names
        if !languageDef.functionPattern.isEmpty {
            highlight(pattern: languageDef.functionPattern, in: attributedString, with: syntaxColors["function"]!)
        }

        return attributedString
    }

    private static func colorToNative(_ color: Color) -> Any {
        #if os(macOS)
        return NSColor(color)
        #else
        return UIColor(color)
        #endif
    }
}
