//
//  LanguageDetection.swift
//  CueApp
//

enum LanguageDetection {
    static func detectLanguage(_ code: String) -> String {
        if code.contains("import SwiftUI") || code.contains("struct") && code.contains(": View") {
            return "swift"
        } else if code.contains("func") && code.contains("->") {
            return "swift"
        } else if code.contains("import Foundation") {
            return "swift"
        } else if code.contains("interface") || code.contains("class") && code.contains("extends") {
            return "java"
        } else if code.contains("fun") && code.contains("val") {
            return "kotlin"
        } else if code.contains("def") && code.contains("self") {
            return "python"
        }

        // Default to plaintext if no language is detected
        return ""
    }
}
