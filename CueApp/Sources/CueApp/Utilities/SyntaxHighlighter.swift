import SwiftUI

public struct LanguageDefinition {
    public let keywords: [String]
    public let commentPattern: String
    public let stringPattern: String

    public init(keywords: [String], commentPattern: String, stringPattern: String) {
        self.keywords = keywords
        self.commentPattern = commentPattern
        self.stringPattern = stringPattern
    }
}

public var languageDefinitions: [String: LanguageDefinition] {
    [
        "swift": LanguageDefinition(
            keywords: ["class", "struct", "enum", "protocol", "func", "var", "let", "if", "else", "guard",
                      "return", "true", "false", "nil", "self", "super", "init", "deinit", "get", "set",
                      "willSet", "didSet", "throws", "throw", "rethrows", "try", "catch", "async", "await",
                      "public", "private", "fileprivate", "internal", "static", "final", "override",
                      "mutating", "nonmutating", "dynamic", "weak", "unowned", "required", "optional",
                      "switch", "case", "default", "break", "continue", "fallthrough", "where", "while",
                      "for", "in", "repeat", "defer", "import", "typealias", "associatedtype", "extension"],
            commentPattern: "\\/\\/.*?$|\\/\\*[\\s\\S]*?\\*\\/",
            stringPattern: "\"[^\"\\n]*\"|\".*?\\\\\\(.*?\\).*?\""
        ),
        "python": LanguageDefinition(
            keywords: ["False", "None", "True", "and", "as", "assert", "async", "await", "break", "class",
                      "continue", "def", "del", "elif", "else", "except", "finally", "for", "from", "global",
                      "if", "import", "in", "is", "lambda", "nonlocal", "not", "or", "pass", "raise",
                      "return", "try", "while", "with", "yield"],
            commentPattern: "#.*?$",
            stringPattern: "(\"|'){1,3}[^\"']*?\\1{1,3}|(\"|'){1,3}.*?[^\\\\]\\2{1,3}"
        ),
        "javascript": LanguageDefinition(
            keywords: ["break", "case", "catch", "class", "const", "continue", "debugger", "default",
                      "delete", "do", "else", "export", "extends", "finally", "for", "function", "if",
                      "import", "in", "instanceof", "new", "return", "super", "switch", "this", "throw",
                      "try", "typeof", "var", "void", "while", "with", "yield", "let", "static", "enum",
                      "await", "async", "null", "undefined", "true", "false"],
            commentPattern: "\\/\\/.*?$|\\/\\*[\\s\\S]*?\\*\\/",
            stringPattern: "\"[^\"\\n]*\"|'[^'\\n]*'|`[^`]*`"
        ),
        "typescript": LanguageDefinition(
            keywords: ["break", "case", "catch", "class", "const", "continue", "debugger", "default",
                      "delete", "do", "else", "export", "extends", "finally", "for", "function", "if",
                      "import", "in", "instanceof", "new", "return", "super", "switch", "this", "throw",
                      "try", "typeof", "var", "void", "while", "with", "yield", "let", "static", "enum",
                      "await", "async", "null", "undefined", "true", "false",
                      // TypeScript-specific keywords
                      "interface", "type", "implements", "namespace", "module", "declare", "abstract",
                      "as", "any", "boolean", "number", "string", "symbol", "never", "unknown",
                      "object", "keyof", "readonly", "is", "unique", "infer", "public", "private",
                      "protected", "override", "satisfies", "asserts", "out", "in"],
            commentPattern: "\\/\\/.*?$|\\/\\*[\\s\\S]*?\\*\\/",
            stringPattern: "\"[^\"\\n]*\"|'[^'\\n]*'|`[^`]*`"
        )
    ]
}

public func syntaxColors(_ _colorScheme: ColorScheme) -> [String: Color] {
    if _colorScheme == .light {
        return [
            "default": Color.black,                                        // Default text color
            "keyword": Color(red: 0.607, green: 0.156, blue: 0.560),      // Purple for keywords
            "string": Color(red: 0.800, green: 0.063, blue: 0.063),       // Red for strings
            "comment": Color(red: 0.000, green: 0.456, blue: 0.000),      // Green for comments
            "number": Color.black,                                         // Black for numbers
            "type": Color.black,                                          // Black for types
            "function": Color.black,                                      // Black for functions
            "property": Color.black                                       // Black for properties
        ]
    } else {
        return [
            "default": Color.white,                                       // Default text color
            "keyword": Color(red: 0.776, green: 0.472, blue: 0.768),     // Light purple for keywords
            "string": Color(red: 0.859, green: 0.171, blue: 0.219),      // Light red for strings
            "comment": Color(red: 0.300, green: 0.686, blue: 0.300),     // Light green for comments
            "number": Color.white,                                        // White for numbers
            "type": Color.white,                                         // White for types
            "function": Color.white,                                     // White for functions
            "property": Color.white                                      // White for properties
        ]
    }
}

private func highlight(pattern: String, in attributedString: NSMutableAttributedString, with color: Color) {
    do {
        let regex = try NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
        let range = NSRange(location: 0, length: attributedString.length)
        let matches = regex.matches(in: attributedString.string, range: range)

        for match in matches {
            attributedString.addAttribute(
                .foregroundColor,
                value: colorToNative(color),
                range: match.range
            )
        }
    } catch {
        print("Regex error: \(error)")
    }
}

public func highlightedCode(colorScheme: ColorScheme, language: String, code: String) -> NSAttributedString {
    let syntaxColors = syntaxColors(colorScheme)
    let attributedString = NSMutableAttributedString(string: code)

    // Set default color first
    attributedString.addAttribute(
        .foregroundColor,
        value: colorToNative(colorScheme == .light ? syntaxColors["default"]! : Color.white),
        range: NSRange(location: 0, length: attributedString.length)
    )

    // Get language definition
    let languageDef = languageDefinitions[language.lowercased()] ?? languageDefinitions["plaintext"] ??
        LanguageDefinition(keywords: [], commentPattern: "", stringPattern: "")

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

    return attributedString
}

func colorToNative(_ color: Color) -> Any {
    #if os(macOS)
    return NSColor(color)
    #else
    return UIColor(color)
    #endif
}
