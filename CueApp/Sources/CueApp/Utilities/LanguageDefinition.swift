import SwiftUI

public struct LanguageDefinition: Sendable {
    public let keywords: [String]
    public let commentPattern: String
    public let stringPattern: String
    public let typePattern: String
    public let numberPattern: String
    public let functionPattern: String
    public let propertyPattern: String
    public let bindingPattern: String
    public let markdownPatterns: [(pattern: String, type: String)]

    public init(
        keywords: [String],
        commentPattern: String,
        stringPattern: String,
        typePattern: String,
        numberPattern: String,
        functionPattern: String = "",
        propertyPattern: String = "",
        bindingPattern: String = "",
        markdownPatterns: [(pattern: String, type: String)] = []
    ) {
        self.keywords = keywords
        self.commentPattern = commentPattern
        self.stringPattern = stringPattern
        self.typePattern = typePattern
        self.numberPattern = numberPattern
        self.functionPattern = functionPattern
        self.propertyPattern = propertyPattern
        self.bindingPattern = bindingPattern
        self.markdownPatterns = markdownPatterns
    }
}

public struct LanguageDefinitions {
    public static func getDefinition(for language: String) -> LanguageDefinition {
        return definitions[language.lowercased()] ?? definitions["plaintext"]!
    }

    public static let definitions: [String: LanguageDefinition] = [
        "json": LanguageDefinition(
            keywords: ["true", "false", "null"],
            commentPattern: "",
            stringPattern: "['\"](?:[^'\"\\\\]|\\\\.)*['\"]",
            typePattern: "",
            numberPattern: "-?\\b\\d+(\\.\\d+)?([eE][+-]?\\d+)?\\b",
            propertyPattern: "['\"][^'\"]+['\"](?=\\s*:)"
        ),

        "markdown": LanguageDefinition(
            keywords: [],
            commentPattern: "",
            stringPattern: "",
            typePattern: "",
            numberPattern: "",
            functionPattern: "",
            propertyPattern: "",
            bindingPattern: "",
            markdownPatterns: [
                // Bold - using negative lookbehind to avoid matches inside code blocks
                ("(?<!`.*?)\\*\\*.*?\\*\\*(?!.*?`)|(?<!`.*?)__.*?__(?!.*?`)", "bold"),

                // Italic - using negative lookbehind to avoid matches inside code blocks
                ("(?<!`.*?)\\*[^*]+\\*(?!.*?`)|(?<!`.*?)_[^_]+_(?!.*?`)", "italic"),

                // Links
                ("\\[([^\\]]+)\\]\\(([^\\)]+)\\)", "link"),

                // Images
                ("!\\[([^\\]]+)\\]\\(([^\\)]+)\\)", "image"),

                // Blockquotes - using negative lookbehind to avoid matches inside code blocks
                ("(?<!`{3}\\n.*)^>\\s.*$", "blockquote"),

                // Lists (will be transformed to dots in the text transformation step)
                ("^\\s*•\\s.*$", "list"),

                // Ordered lists
                ("^\\s*\\d+\\.\\s.*$", "orderedlist"),

                // Horizontal rules
                ("^\\s*([-*_]\\s*){3,}$", "hr"),

                // Code blocks
                ("```[\\s\\S]*?```", "code"),

                // Inline code
                ("`[^`]+`", "code")
            ]
        ),

        "python": LanguageDefinition(
            keywords: ["False", "None", "True", "and", "as", "assert", "async", "await", "break", "class",
                      "continue", "def", "del", "elif", "else", "except", "finally", "for", "from", "global",
                      "if", "import", "in", "is", "lambda", "nonlocal", "not", "or", "pass", "raise",
                      "return", "try", "while", "with", "yield"],
            commentPattern: "#.*?$",
            stringPattern: "(\"|'){1,3}[^\"']*?\\1{1,3}|(\"|'){1,3}.*?[^\\\\]\\2{1,3}",
            typePattern: "\\b(int|float|bool|str|list|dict|set|tuple|None|object|bytes|complex|range|frozenset|type|slice)\\b",
            numberPattern: "\\b\\d+\\.\\d+\\b|\\b\\d+\\b",
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
            typePattern: "\\b([A-Z][A-Za-z0-9_]*)\\b(?=\\s*[\\{\\(])|\\b([A-Z][A-Za-z0-9_]*)<[^>]+>\\b",
            numberPattern: "\\b\\d+\\.\\d+\\b|\\b\\d+\\b",
            functionPattern: "\\bfunc\\s+([a-zA-Z_][a-zA-Z0-9_]*)",
            propertyPattern: "@[A-Za-z_][A-Za-z0-9_]*",
            bindingPattern: "\\$[A-Za-z_][A-Za-z0-9_]*"
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
            typePattern: "\\b(Int|Double|Float|Boolean|String|Char|Long|Short|Byte|Any|Unit|List|Map|Set|Array|CustomType)\\b",
            numberPattern: "\\b\\d+\\.\\d+\\b|\\b\\d+\\b",
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
            typePattern: "\\b(int|float|double|char|bool|long|short|unsigned|signed|void|wchar_t|size_t|CustomType)\\b",
            numberPattern: "\\b\\d+\\.\\d+\\b|\\b\\d+\\b",
            functionPattern: "\\b[A-Za-z0-9_<>]+\\s+([a-zA-Z_][a-zA-Z0-9_]*)\\s*\\("
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
            typePattern: "\\b(int|int8|int16|int32|int64|uint|uint8|uint16|uint32|uint64|uintptr|float32|float64|complex64|complex128|bool|string|byte|rune|CustomType)\\b",
            numberPattern: "\\b\\d+\\.\\d+\\b|\\b\\d+\\b",
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
            typePattern: "\\b(Number|String|Boolean|Object|Array|Function|Symbol|BigInt|Date|RegExp|Map|Set|WeakMap|WeakSet|CustomType)\\b",
            numberPattern: "\\b\\d+\\.\\d+\\b|\\b\\d+\\b",
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
            typePattern: "\\b(Number|String|Boolean|Object|Array|Function|Symbol|BigInt|Date|RegExp|Map|Set|WeakMap|WeakSet|CustomType)\\b",
            numberPattern: "\\b\\d+\\.\\d+\\b|\\b\\d+\\b",
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
            typePattern: "\\b(Integer|Double|Float|Boolean|String|Character|Long|Short|Byte|Object|Void|CustomType)\\b",
            numberPattern: "\\b\\d+\\.\\d+\\b|\\b\\d+\\b",
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
            typePattern: "\\b(String|i32|u32|f64|bool|char|Vec|Option|Result|HashMap|HashSet|CustomType)\\b",
            numberPattern: "\\b\\d+\\.\\d+\\b|\\b\\d+\\b",
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
            typePattern: "\\b(Int32|Double|Float|Boolean|String|Char|Long|Short|Byte|Object|Void|CustomType)\\b",
            numberPattern: "\\b\\d+\\.\\d+\\b|\\b\\d+\\b",
            functionPattern: "\\b[A-Za-z0-9_<>]+\\s+([a-zA-Z_][a-zA-Z0-9_]*)\\s*\\("
        ),

        "plaintext": LanguageDefinition(
            keywords: [],
            commentPattern: "",
            stringPattern: "",
            typePattern: "",
            numberPattern: "",
            functionPattern: ""
        )
    ]
}
