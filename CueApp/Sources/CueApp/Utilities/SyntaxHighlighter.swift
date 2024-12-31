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
                "property": Color.black,
                "binding": Color.black
            ]
        } else {
            return [
                "default": Color(red: 0.85, green: 0.85, blue: 0.85), // Slightly Grayish White
                "keyword": Color(red: 0.776, green: 0.472, blue: 0.768),
                "string": Color(red: 0.56, green: 0.93, blue: 0.56), // Light Green
                "comment": Color(red: 0.6, green: 0.6, blue: 0.6),
                "number": Color(hex: "#D19A66"),
                "type": Color(hex: "#D19A66"),
                "function": Color(hex: "#61AFEF"),
                "property": Color(hex: "#D19A66"),
                "binding": Color(hex: "#D19A66"),
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

        // Type names
        if !languageDef.typePattern.isEmpty {
            highlight(pattern: languageDef.typePattern, in: attributedString, with: syntaxColors["type"]!)
        }

        // Number literals
        if !languageDef.numberPattern.isEmpty {
            highlight(pattern: languageDef.numberPattern, in: attributedString, with: syntaxColors["number"]!)
        }

        // Function names
        if !languageDef.functionPattern.isEmpty {
            highlight(pattern: languageDef.functionPattern, in: attributedString, with: syntaxColors["function"]!)
        }

        // Property wrappers
        if !languageDef.propertyPattern.isEmpty {
            highlight(pattern: languageDef.propertyPattern, in: attributedString, with: syntaxColors["property"]!)
        }

        // Bindings
        if !languageDef.bindingPattern.isEmpty {
            highlight(pattern: languageDef.bindingPattern, in: attributedString, with: syntaxColors["binding"]!)
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

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
