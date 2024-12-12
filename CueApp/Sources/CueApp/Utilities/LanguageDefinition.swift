import SwiftUI

public struct LanguageDefinition: Sendable {
    public let keywords: [String]
    public let commentPattern: String
    public let stringPattern: String
    public let functionPattern: String

    public init(keywords: [String], commentPattern: String, stringPattern: String, functionPattern: String = "") {
        self.keywords = keywords
        self.commentPattern = commentPattern
        self.stringPattern = stringPattern
        self.functionPattern = functionPattern
    }
}

public struct LanguageDefinitions {
    public static let definitions: [String: LanguageDefinition] = [
        "swift": LanguageDefinition(
            keywords: ["class", "struct", "enum", "protocol", "func", "var", "let", "if", "else", "guard",
                      "return", "true", "false", "nil", "self", "super", "init", "deinit", "get", "set",
                      "willSet", "didSet", "throws", "throw", "rethrows", "try", "catch", "async", "await",
                      "public", "private", "fileprivate", "internal", "static", "final", "override",
                      "mutating", "nonmutating", "dynamic", "weak", "unowned", "required", "optional",
                      "switch", "case", "default", "break", "continue", "fallthrough", "where", "while",
                      "for", "in", "repeat", "defer", "import", "typealias", "associatedtype", "extension"],
            commentPattern: "\\/\\/.*?$|\\/\\*[\\s\\S]*?\\*\\/",
            stringPattern: "\"[^\"\\n]*\"|\".*?\\\\\\(.*?\\).*?\"",
            functionPattern: "\\bfunc\\s+([a-zA-Z_][a-zA-Z0-9_]*)"
        ),

        "python": LanguageDefinition(
            keywords: ["False", "None", "True", "and", "as", "assert", "async", "await", "break", "class",
                      "continue", "def", "del", "elif", "else", "except", "finally", "for", "from", "global",
                      "if", "import", "in", "is", "lambda", "nonlocal", "not", "or", "pass", "raise",
                      "return", "try", "while", "with", "yield"],
            commentPattern: "#.*?$",
            stringPattern: "(\"|'){1,3}[^\"']*?\\1{1,3}|(\"|'){1,3}.*?[^\\\\]\\2{1,3}",
            functionPattern: "\\bdef\\s+([a-zA-Z_][a-zA-Z0-9_]*)"
        ),

        "javascript": LanguageDefinition(
            keywords: ["break", "case", "catch", "class", "const", "continue", "debugger", "default",
                      "delete", "do", "else", "export", "extends", "finally", "for", "function", "if",
                      "import", "in", "instanceof", "new", "return", "super", "switch", "this", "throw",
                      "try", "typeof", "var", "void", "while", "with", "yield", "let", "static", "enum",
                      "await", "async", "null", "undefined", "true", "false"],
            commentPattern: "\\/\\/.*?$|\\/\\*[\\s\\S]*?\\*\\/",
            stringPattern: "\"[^\"\\n]*\"|'[^'\\n]*'|`[^`]*`",
            functionPattern: "\\bfunction\\s+([a-zA-Z_][a-zA-Z0-9_]*)"
        ),

        "typescript": LanguageDefinition(
            keywords: ["break", "case", "catch", "class", "const", "continue", "debugger", "default",
                      "delete", "do", "else", "export", "extends", "finally", "for", "function", "if",
                      "import", "in", "instanceof", "new", "return", "super", "switch", "this", "throw",
                      "try", "typeof", "var", "void", "while", "with", "yield", "let", "static", "enum",
                      "await", "async", "null", "undefined", "true", "false",
                      "interface", "type", "implements", "namespace", "module", "declare", "abstract",
                      "as", "any", "boolean", "number", "string", "symbol", "never", "unknown",
                      "object", "keyof", "readonly", "is", "unique", "infer", "public", "private",
                      "protected", "override", "satisfies", "asserts", "out", "in"],
            commentPattern: "\\/\\/.*?$|\\/\\*[\\s\\S]*?\\*\\/",
            stringPattern: "\"[^\"\\n]*\"|'[^'\\n]*'|`[^`]*`",
            functionPattern: "\\bfunction\\s+([a-zA-Z_][a-zA-Z0-9_]*)"
        ),

        "java": LanguageDefinition(
            keywords: ["abstract", "assert", "boolean", "break", "byte", "case", "catch", "char", "class",
                      "const", "continue", "default", "do", "double", "else", "enum", "extends", "final",
                      "finally", "float", "for", "if", "implements", "import", "instanceof", "int",
                      "interface", "long", "native", "new", "package", "private", "protected", "public",
                      "return", "short", "static", "strictfp", "super", "switch", "synchronized", "this",
                      "throw", "throws", "transient", "try", "void", "volatile", "while", "true", "false",
                      "null"],
            commentPattern: "\\/\\/.*?$|\\/\\*[\\s\\S]*?\\*\\/",
            stringPattern: "\"[^\"\\n]*\"",
            functionPattern: "\\b[A-Za-z0-9_<>]+\\s+([a-zA-Z_][a-zA-Z0-9_]*)\\s*\\("
        ),

        "rust": LanguageDefinition(
            keywords: ["as", "break", "const", "continue", "crate", "else", "enum", "extern", "false",
                      "fn", "for", "if", "impl", "in", "let", "loop", "match", "mod", "move", "mut",
                      "pub", "ref", "return", "self", "Self", "static", "struct", "super", "trait",
                      "true", "type", "unsafe", "use", "where", "while", "async", "await", "dyn",
                      "abstract", "become", "box", "do", "final", "macro", "override", "priv", "try",
                      "typeof", "unsized", "virtual", "yield"],
            commentPattern: "\\/\\/.*?$|\\/\\*[\\s\\S]*?\\*\\/",
            stringPattern: "\"[^\"\\n]*\"|'[^'\\n]*'",
            functionPattern: "\\bfn\\s+([a-zA-Z_][a-zA-Z0-9_]*)"
        ),

        "plaintext": LanguageDefinition(
            keywords: [],
            commentPattern: "",
            stringPattern: ""
        )
    ]

    public static func getDefinition(for language: String) -> LanguageDefinition {
        return definitions[language.lowercased()] ?? definitions["plaintext"]!
    }
}
