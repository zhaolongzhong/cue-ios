import SwiftUI
import os

public struct SyntaxHighlighter {
    static let log = Logger(subsystem: "SyntaxHighlighter", category: "SyntaxHighlighter")

    public static func syntaxColors(_ colorScheme: ColorScheme) -> [String: Color] {
        var colors = colorScheme == .light ? [
            "default": Color.black,
            "keyword": Color(red: 0.607, green: 0.156, blue: 0.560),
            "string": Color(red: 0.800, green: 0.063, blue: 0.063),
            "comment": Color(red: 0.000, green: 0.456, blue: 0.000),
            "number": Color.black,
            "type": Color.black,
            "function": Color.black,
            "property": Color.black,
            "binding": Color.black
        ] : [
            "default": Color(red: 0.85, green: 0.85, blue: 0.85),
            "keyword": Color(red: 0.776, green: 0.472, blue: 0.768),
            "string": Color(red: 0.56, green: 0.93, blue: 0.56),
            "comment": Color(red: 0.6, green: 0.6, blue: 0.6),
            "number": Color(hex: "#D19A66"),
            "type": Color(hex: "#D19A66"),
            "function": Color(hex: "#61AFEF"),
            "property": Color(hex: "#D19A66"),
            "binding": Color(hex: "#D19A66")
        ]

        // Add Markdown-specific colors
        let markdownColors: [String: Color] = colorScheme == .light ? [
            "header": Color(red: 0.607, green: 0.156, blue: 0.560),
            "bold": Color.black.opacity(0.9),
            "italic": Color.black.opacity(0.9),
            "link": Color(hex: "#0969DA"),
            "image": Color(hex: "#0969DA"),
            "blockquote": Color(red: 0.000, green: 0.456, blue: 0.000),
            "list": Color.black,
            "orderedlist": Color.blue,
            "hr": Color(hex: "#57606A"),
            "code": Color(red: 0.800, green: 0.063, blue: 0.063),
            "nested-code": Color(red: 0.800, green: 0.063, blue: 0.063)
        ] : [
            "header": Color(red: 0.776, green: 0.472, blue: 0.768),
            "bold": Color.white.opacity(0.9),
            "italic": Color.white.opacity(0.9),
            "link": Color(hex: "#539BF5"),
            "image": Color(hex: "#539BF5"),
            "blockquote": Color(red: 0.56, green: 0.93, blue: 0.56),
            "list": Color.white,
            "orderedlist": Color(hex: "#61AFEF"),
            "hr": Color(hex: "#768390"),
            "code": Color(hex: "#F47067"),
            "nested-code": Color(hex: "#F47067")
        ]

        colors.merge(markdownColors) { current, _ in current }
        return colors
    }

    static func highlight(pattern: String, in attributedString: NSMutableAttributedString, with color: Color) {
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
        let languageDef = LanguageDefinitions.getDefinition(for: language)
        let defaultFont = NSFont.systemFont(ofSize: 14)
        attributedString.addAttribute(
            .font,
            value: defaultFont,
            range: NSRange(location: 0, length: attributedString.length)
        )

        attributedString.addAttribute(
            .foregroundColor,
            value: colorToNative(syntaxColors["default"]!),
            range: NSRange(location: 0, length: attributedString.length)
        )

        if language.lowercased() == "markdown" {
            highlightMarkdown(attributedString, syntaxColors: syntaxColors)
        } else {
            // Standard language highlighting
            if !languageDef.commentPattern.isEmpty {
                highlight(pattern: languageDef.commentPattern, in: attributedString, with: syntaxColors["comment"]!)
            }

            if !languageDef.keywords.isEmpty {
                let keywordPattern = "\\b(" + languageDef.keywords.joined(separator: "|") + ")\\b"
                highlight(pattern: keywordPattern, in: attributedString, with: syntaxColors["keyword"]!)
            }

            if !languageDef.stringPattern.isEmpty {
                highlight(pattern: languageDef.stringPattern, in: attributedString, with: syntaxColors["string"]!)
            }

            if !languageDef.typePattern.isEmpty {
                highlight(pattern: languageDef.typePattern, in: attributedString, with: syntaxColors["type"]!)
            }

            if !languageDef.numberPattern.isEmpty {
                highlight(pattern: languageDef.numberPattern, in: attributedString, with: syntaxColors["number"]!)
            }

            if !languageDef.functionPattern.isEmpty {
                highlight(pattern: languageDef.functionPattern, in: attributedString, with: syntaxColors["function"]!)
            }

            if !languageDef.propertyPattern.isEmpty {
                highlight(pattern: languageDef.propertyPattern, in: attributedString, with: syntaxColors["property"]!)
            }

            if !languageDef.bindingPattern.isEmpty {
                highlight(pattern: languageDef.bindingPattern, in: attributedString, with: syntaxColors["binding"]!)
            }
        }

        return attributedString
    }

    static func colorToNative(_ color: Color) -> Any {
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
