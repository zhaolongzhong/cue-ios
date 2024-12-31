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
        "python": LanguageDefinition(
            keywords: ["False", "None", "True", "and", "as", "assert", "async", "await", "break", "class",
                      "continue", "def", "del", "elif", "else", "except", "finally", "for", "from", "global",
                      "if", "import", "in", "is", "lambda", "nonlocal", "not", "or", "pass", "raise",
                      "return", "try", "while", "with", "yield"],
            commentPattern: "#.*?$",
            stringPattern: "(\"|'){1,3}[^\"']*?\\1{1,3}|(\"|'){1,3}.*?[^\\\\]\\2{1,3}",
            functionPattern: "\\bdef\\s+([a-zA-Z_][a-zA-Z0-9_]*)"
        ),

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

        "kotlin": LanguageDefinition(
            keywords: ["as", "break", "class", "continue", "do", "else", "false", "for", "fun", "if", "in",
                      "interface", "is", "null", "object", "package", "return", "super", "this", "throw",
                      "true", "try", "typealias", "val", "var", "when", "while", "by", "catch", "constructor",
                      "delegate", "dynamic", "field", "file", "finally", "get", "import", "init", "param",
                      "property", "receiver", "set", "setparam", "where", "actual", "abstract", "annotation",
                      "companion", "const", "crossinline", "data", "enum", "expect", "external", "final",
                      "infix", "inner", "internal", "lateinit", "noinline", "open", "operator", "out",
                      "override", "private", "protected", "public", "reified", "sealed", "suspend", "tailrec",
                      "vararg", "field", "it"],
            commentPattern: "\\/\\/.*?$|\\/\\*[\\s\\S]*?\\*\\/",
            stringPattern: "\"\"\"[\\s\\S]*?\"\"\"|\"[^\"\\n]*\"|'[^'\\n]*'",
            functionPattern: "\\bfun\\s+([a-zA-Z_][a-zA-Z0-9_]*)"
        ),

        "cpp": LanguageDefinition(
            keywords: ["asm", "auto", "bool", "break", "case", "catch", "char", "class", "const",
                      "const_cast", "continue", "default", "delete", "do", "double", "dynamic_cast",
                      "else", "enum", "explicit", "export", "extern", "false", "float", "for", "friend",
                      "goto", "if", "inline", "int", "long", "mutable", "namespace", "new", "operator",
                      "private", "protected", "public", "register", "reinterpret_cast", "return", "short",
                      "signed", "sizeof", "static", "static_cast", "struct", "switch", "template", "this",
                      "throw", "true", "try", "typedef", "typeid", "typename", "union", "unsigned", "using",
                      "virtual", "void", "volatile", "wchar_t", "while", "and", "and_eq", "bitand",
                      "bitor", "compl", "not", "not_eq", "or", "or_eq", "xor", "xor_eq"],
            commentPattern: "\\/\\/.*?$|\\/\\*[\\s\\S]*?\\*\\/",
            stringPattern: "\"[^\"\\n]*\"|'[^'\\n]*'",
            functionPattern: "\\b[A-Za-z0-9_]+\\s+([a-zA-Z_][a-zA-Z0-9_]*)\\s*\\("
        ),

        "go": LanguageDefinition(
            keywords: ["break", "case", "chan", "const", "continue", "default", "defer", "else",
                      "fallthrough", "for", "func", "go", "goto", "if", "import", "interface",
                      "map", "package", "range", "return", "select", "struct", "switch", "type",
                      "var", "true", "false", "iota", "nil", "int", "int8", "int16", "int32",
                      "int64", "uint", "uint8", "uint16", "uint32", "uint64", "uintptr",
                      "float32", "float64", "complex64", "complex128", "bool", "byte", "rune",
                      "string", "error", "make", "len", "cap", "new", "append", "copy", "close",
                      "delete", "complex", "real", "imag", "panic", "recover"],
            commentPattern: "\\/\\/.*?$|\\/\\*[\\s\\S]*?\\*\\/",
            stringPattern: "`[^`]*`|\"[^\"\\n]*\"|'[^'\\n]*'",
            functionPattern: "\\bfunc\\s+([a-zA-Z_][a-zA-Z0-9_]*)"
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

        "csharp": LanguageDefinition(
            keywords: ["abstract", "as", "base", "bool", "break", "byte", "case", "catch", "char",
                      "checked", "class", "const", "continue", "decimal", "default", "delegate", "do",
                      "double", "else", "enum", "event", "explicit", "extern", "false", "finally",
                      "fixed", "float", "for", "foreach", "goto", "if", "implicit", "in", "int",
                      "interface", "internal", "is", "lock", "long", "namespace", "new", "null",
                      "object", "operator", "out", "override", "params", "private", "protected",
                      "public", "readonly", "ref", "return", "sbyte", "sealed", "short", "sizeof",
                      "stackalloc", "static", "string", "struct", "switch", "this", "throw", "true",
                      "try", "typeof", "uint", "ulong", "unchecked", "unsafe", "ushort", "using",
                      "virtual", "void", "volatile", "while", "add", "alias", "ascending",
                      "async", "await", "by", "descending", "dynamic", "equals", "from", "get",
                      "global", "group", "into", "join", "let", "nameof", "on", "orderby",
                      "partial", "remove", "select", "set", "value", "var", "when", "where",
                      "yield"],
            commentPattern: "\\/\\/.*?$|\\/\\*[\\s\\S]*?\\*\\/",
            stringPattern: "@\"[^\"]*\"|\"[^\"\\n]*\"|'[^'\\n]*'",
            functionPattern: "\\b[A-Za-z0-9_<>]+\\s+([a-zA-Z_][a-zA-Z0-9_]*)\\s*\\("
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
