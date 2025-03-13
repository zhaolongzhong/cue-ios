//
//  MarkdownHighlighter.swift
//  CueApp
//
import SwiftUI
import os

struct MarkdownHighlighter {
    private let colorScheme: ColorScheme
    private let logger = Logger(subsystem: "MarkdownHighlighter", category: "MarkdownHighlighter")

    #if os(iOS)
    private let defaultFont = UIFont.preferredFont(forTextStyle: .body)
    private let monospacedFont = UIFont(name: "SF Mono", size: 14) ?? UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    #elseif os(macOS)
    private let defaultFont = NSFont.preferredFont(forTextStyle: .body)
    private let monospacedFont = NSFont(name: "SF Mono", size: 14) ?? NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    #endif

    init(colorScheme: ColorScheme) {
          self.colorScheme = colorScheme
      }

    func process(_ content: String) -> NSAttributedString {
        let processedContent = convertDashesToDots(content)

        // Check if the content might be code with keyword highlighting
        if processedContent.contains("**struct**") ||
           processedContent.contains("**class**") ||
           processedContent.contains("**func**") ||
           processedContent.contains("**import**") {
            return highlightAsCode(processedContent)
        } else {
            return highlightAsMarkdown(processedContent)
        }
    }

    private func highlightAsMarkdown(_ text: String) -> NSAttributedString {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Create a mutable attributed string with the cleaned text
        let attributedString = NSMutableAttributedString(string: text)

        // Set the default font for the entire text
        attributedString.addAttribute(
            .font,
            value: defaultFont,
            range: NSRange(location: 0, length: attributedString.length)
        )

        // Apply default text color
        attributedString.addAttribute(
            .foregroundColor,
            value: colorScheme == .dark ? Color.white : Color.black,
            range: NSRange(location: 0, length: attributedString.length)
        )

        // Get syntax colors from SyntaxHighlighter
        let syntaxColors = SyntaxHighlighter.syntaxColors(colorScheme, markdownMessage: true)

        // Process and apply markdown styling (this will modify the attributedString)
        let processedString = cleanAndProcessMarkdown(attributedString, syntaxColors: syntaxColors, monospacedFont: monospacedFont)

        return processedString
    }

    private func cleanAndProcessMarkdown(_ attributedString: NSMutableAttributedString, syntaxColors: [String: Color], monospacedFont: Any) -> NSAttributedString {
        let text = attributedString.string
        let mutableResult = NSMutableAttributedString(string: "")

        // Split the text into lines to process each line separately
        let lines = text.components(separatedBy: "\n")

        for (lineIndex, line) in lines.enumerated() {
            // For empty lines, just add a newline character (unless it's the last line)
            if line.isEmpty {
                if lineIndex < lines.count - 1 {
                    mutableResult.append(NSAttributedString(string: "\n"))
                }
                continue // Skip further processing for empty lines
            }

            // Process headers
            let processedLine: NSAttributedString
            if let result = processHeader(line, syntaxColors: syntaxColors) {
                processedLine = result
            }
            // Process bullet points
            else if let result = processBulletPoint(line, syntaxColors: syntaxColors) {
                processedLine = result
            }
            // Process numbered lists
            else if let result = processNumberedList(line, syntaxColors: syntaxColors) {
                processedLine = result
            }
            // Process blockquotes
            else if let result = processBlockquote(line, syntaxColors: syntaxColors) {
                processedLine = result
            }
            // Process regular text with inline formatting
            else {
                processedLine = processInlineFormatting(line, syntaxColors: syntaxColors, monospacedFont: monospacedFont)
            }

            mutableResult.append(processedLine)

            // Add newline if this isn't the last line
            if lineIndex < lines.count - 1 {
                mutableResult.append(NSAttributedString(string: "\n"))
            }
        }

        return mutableResult
    }

    private func highlightAsCode(_ text: String) -> NSAttributedString {
        // Remove the ** markers around keywords to get clean code for syntax highlighting
        let cleanedCode = text.replacingOccurrences(of: "\\*\\*(\\w+)\\*\\*", with: "$1", options: .regularExpression)

        // Detect language based on content patterns
        let language = LanguageDetection.detectLanguage(cleanedCode)

        return SyntaxHighlighter.highlightedCode(colorScheme: colorScheme, language: language, code: cleanedCode)
    }

    // Process header lines (e.g., "# Header")
    private func processHeader(_ line: String, syntaxColors: [String: Color]) -> NSAttributedString? {
        let headerPattern = "^(#{1,6})\\s+(.+)$"

        do {
            let regex = try NSRegularExpression(pattern: headerPattern, options: [.anchorsMatchLines])
            let nsRange = NSRange(line.startIndex..., in: line)

            if let match = regex.firstMatch(in: line, range: nsRange), match.numberOfRanges > 2 {
                let contentRange = match.range(at: 2)

                guard let headerContentRange = Range(contentRange, in: line) else { return nil }
                let headerContent = String(line[headerContentRange])
                let headerLevel = match.range(at: 1).length

                let attributedHeader = NSMutableAttributedString(string: headerContent)

                #if os(iOS)
                let fontSize: CGFloat
                switch headerLevel {
                case 1: fontSize = defaultFont.pointSize * 1.5
                case 2: fontSize = defaultFont.pointSize * 1.3
                case 3: fontSize = defaultFont.pointSize * 1.3
                case 4: fontSize = defaultFont.pointSize * 1
                case 5: fontSize = defaultFont.pointSize * 1
                default: fontSize = defaultFont.pointSize
                }

                let headerFont = UIFont.systemFont(ofSize: fontSize, weight: .bold)
                #elseif os(macOS)
                let fontSize: CGFloat
                switch headerLevel {
                case 1: fontSize = defaultFont.pointSize * 1.5
                case 2: fontSize = defaultFont.pointSize * 1.3
                case 3: fontSize = defaultFont.pointSize * 1.3
                case 4: fontSize = defaultFont.pointSize * 1
                case 5: fontSize = defaultFont.pointSize * 1
                default: fontSize = defaultFont.pointSize
                }

                let headerFont = NSFont.systemFont(ofSize: fontSize, weight: .bold)
                #endif

                // Apply styling
                attributedHeader.addAttribute(.font, value: headerFont, range: NSRange(location: 0, length: attributedHeader.length))
                attributedHeader.addAttribute(.foregroundColor, value: syntaxColors["header"]!.native, range: NSRange(location: 0, length: attributedHeader.length))

                // Process any inline formatting within the header
                let processedHeader = processInlineFormattingInAttributedString(attributedHeader, syntaxColors: syntaxColors)

                return processedHeader
            }
        } catch {
            logger.error("Header regex error: \(error.localizedDescription)")
        }

        return nil
    }

    // Process bullet points (e.g., "• Item" or "- Item")
    private func processBulletPoint(_ line: String, syntaxColors: [String: Color]) -> NSAttributedString? {
        let bulletPattern = "^\\s*[•\\-\\*]\\s+(.+)$"

        do {
            let regex = try NSRegularExpression(pattern: bulletPattern, options: [.anchorsMatchLines])
            let nsRange = NSRange(line.startIndex..., in: line)

            if let match = regex.firstMatch(in: line, range: nsRange), match.numberOfRanges > 1 {
                var contentRange = match.range(at: 1)

                guard let bulletContentRange = Range(contentRange, in: line) else { return nil }
                let bulletContent = String(line[bulletContentRange])

                // Calculate how much leading whitespace was in the original line
                let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                let leadingSpaceCount = line.count - trimmedLine.count - (line.hasSuffix(" ") ? 1 : 0)
                let leadingSpace = String(repeating: " ", count: leadingSpaceCount)

                let attributedBullet = NSMutableAttributedString(string: "\(leadingSpace)• \(bulletContent)")

                attributedBullet.addAttribute(.font, value: defaultFont, range: NSRange(location: 0, length: attributedBullet.length))
                attributedBullet.addAttribute(
                    .foregroundColor,
                    value: syntaxColors["list"]!.native,
                    range: NSRange(location: leadingSpace.count, length: 1) // Apply color to bullet point
                )

                // Add default text color for content
                attributedBullet.addAttribute(
                    .foregroundColor,
                    value: colorScheme == .dark ? Color.white : Color.black,
                    range: NSRange(location: leadingSpace.count + 2, length: bulletContent.count)
                )

                // Process any inline formatting within the bullet point content
                contentRange = NSRange(location: leadingSpace.count + 2, length: bulletContent.count)
                let mutableContent = NSMutableAttributedString(attributedString: attributedBullet.attributedSubstring(from: contentRange))
                let processedContent = processInlineFormattingInAttributedString(mutableContent, syntaxColors: syntaxColors)

                attributedBullet.replaceCharacters(in: contentRange, with: processedContent)

                return attributedBullet
            }
        } catch {
            logger.error("Bullet point regex error: \(error.localizedDescription)")
        }

        return nil
    }

    // Process numbered lists (e.g., "1. Item")
    private func processNumberedList(_ line: String, syntaxColors: [String: Color]) -> NSAttributedString? {
        let numberedPattern = "^\\s*(\\d+\\.)+\\s+(.+)$"

        do {
            let regex = try NSRegularExpression(pattern: numberedPattern, options: [.anchorsMatchLines])
            let nsRange = NSRange(line.startIndex..., in: line)

            if let match = regex.firstMatch(in: line, range: nsRange), match.numberOfRanges > 2 {
                let numberRange = match.range(at: 1)
                var contentRange = match.range(at: 2)

                guard
                    let numberRangeInString = Range(numberRange, in: line),
                    let contentRangeInString = Range(contentRange, in: line)
                else { return nil }

                let number = String(line[numberRangeInString])
                let listContent = String(line[contentRangeInString])

                // Calculate how much leading whitespace was in the original line
                let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                let leadingSpaceCount = line.count - trimmedLine.count - (line.hasSuffix(" ") ? 1 : 0)
                let leadingSpace = String(repeating: " ", count: leadingSpaceCount)

                let attributedNumberedItem = NSMutableAttributedString(string: "\(leadingSpace)\(number) \(listContent)")

                attributedNumberedItem.addAttribute(.font, value: defaultFont, range: NSRange(location: 0, length: attributedNumberedItem.length))

                // Apply color to number
                attributedNumberedItem.addAttribute(
                    .foregroundColor,
                    value: syntaxColors["orderedlist"]!.native,
                    range: NSRange(location: leadingSpace.count, length: number.count)
                )

                // Add default text color for content
                attributedNumberedItem.addAttribute(
                    .foregroundColor,
                    value: colorScheme == .dark ? Color.white : Color.black,
                    range: NSRange(location: leadingSpace.count + number.count + 1, length: listContent.count)
                )

                // Process any inline formatting within the content
                contentRange = NSRange(location: leadingSpace.count + number.count + 1, length: listContent.count)
                let mutableContent = NSMutableAttributedString(attributedString: attributedNumberedItem.attributedSubstring(from: contentRange))
                let processedContent = processInlineFormattingInAttributedString(mutableContent, syntaxColors: syntaxColors)

                attributedNumberedItem.replaceCharacters(in: contentRange, with: processedContent)

                return attributedNumberedItem
            }
        } catch {
            logger.error("Numbered list regex error: \(error.localizedDescription)")
        }

        return nil
    }

    // Process blockquotes (e.g., "> Quote")
    private func processBlockquote(_ line: String, syntaxColors: [String: Color]) -> NSAttributedString? {
        let blockquotePattern = "^>\\s+(.+)$"

        do {
            let regex = try NSRegularExpression(pattern: blockquotePattern, options: [.anchorsMatchLines])
            let nsRange = NSRange(line.startIndex..., in: line)

            if let match = regex.firstMatch(in: line, range: nsRange), match.numberOfRanges > 1 {
                let contentRange = match.range(at: 1)

                guard let quoteContentRange = Range(contentRange, in: line) else { return nil }
                let quoteContent = String(line[quoteContentRange])

                let attributedQuote = NSMutableAttributedString(string: quoteContent)

                #if os(iOS)
                let italicFont = UIFont.italicSystemFont(ofSize: defaultFont.pointSize)
                #elseif os(macOS)
                let italicFont = NSFont.systemFont(ofSize: defaultFont.pointSize, weight: .light).with(traits: .italic)
                #endif

                attributedQuote.addAttribute(.font, value: italicFont, range: NSRange(location: 0, length: attributedQuote.length))
                attributedQuote.addAttribute(.foregroundColor, value: syntaxColors["blockquote"]!.native, range: NSRange(location: 0, length: attributedQuote.length))

                // Process any inline formatting within the blockquote
                let processedQuote = processInlineFormattingInAttributedString(attributedQuote, syntaxColors: syntaxColors)

                return processedQuote
            }
        } catch {
            logger.error("Blockquote regex error: \(error.localizedDescription)")
        }

        return nil
    }

    // Process inline formatting (bold, italic, code, links)
    private func processInlineFormatting(_ text: String, syntaxColors: [String: Color], monospacedFont: Any) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: text)
        attributedString.addAttribute(.font, value: defaultFont, range: NSRange(location: 0, length: attributedString.length))

        return processInlineFormattingInAttributedString(attributedString, syntaxColors: syntaxColors, monospacedFont: monospacedFont)
    }

    // Process inline formatting within an already created attributed string
    private func processInlineFormattingInAttributedString(_ attributedString: NSMutableAttributedString, syntaxColors: [String: Color], monospacedFont: Any? = nil) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: attributedString)

        // Process code blocks first (they might contain other markdown)
        processPatternsAndReplace(
            "(`.*?`)",
            in: result,
            removeMarkdownChars: true,
            markdownLen: 1, // Remove the ` character
            fontStyle: "code",
            textColor: syntaxColors["code"]!,
            monospacedFont: monospacedFont
        )

        // Process bold text
        processPatternsAndReplace(
            "(\\*\\*.*?\\*\\*)",
            in: result,
            removeMarkdownChars: true,
            markdownLen: 2, // Remove the ** characters
            fontStyle: "bold",
            textColor: syntaxColors["bold"]!
        )

        // Process italic text
        processPatternsAndReplace(
            "(\\*.*?\\*)",
            in: result,
            removeMarkdownChars: true,
            markdownLen: 1, // Remove the * character
            fontStyle: "italic",
            textColor: syntaxColors["italic"]!
        )

        // Process links
        processLinksAndReplace(in: result, textColor: syntaxColors["link"]!)

        return result
    }

    // Helper method to process patterns with regex and replace content while applying styling
    private func processPatternsAndReplace(
        _ pattern: String,
        in attributedString: NSMutableAttributedString,
        removeMarkdownChars: Bool,
        markdownLen: Int,
        fontStyle: String,
        textColor: Color,
        monospacedFont: Any? = nil
    ) {
        let text = attributedString.string

        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let nsRange = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, range: nsRange)

            // Process from the end to avoid range issues when replacing
            for match in matches.reversed() {
                let matchRange = match.range

                guard let range = Range(matchRange, in: text) else { continue }
                let matchedText = String(text[range])

                var cleanContent: String
                if removeMarkdownChars {
                    cleanContent = String(matchedText.dropFirst(markdownLen).dropLast(markdownLen))
                } else {
                    cleanContent = matchedText
                }

                // Create a replacement with clean content but keep attributes
                let replacement = NSMutableAttributedString(string: cleanContent)

                // Apply styling based on font style
                #if os(iOS)
                var styledFont: UIFont

                switch fontStyle {
                case "bold":
                    styledFont = UIFont.boldSystemFont(ofSize: defaultFont.pointSize)
                case "italic":
                    styledFont = UIFont.italicSystemFont(ofSize: defaultFont.pointSize)
                case "code":
                    styledFont = monospacedFont as? UIFont ?? defaultFont
                default:
                    styledFont = defaultFont
                }

                replacement.addAttribute(.font, value: styledFont, range: NSRange(location: 0, length: replacement.length))
                #elseif os(macOS)
                let defaultFont = NSFont.preferredFont(forTextStyle: .body)
                var styledFont: NSFont

                switch fontStyle {
                case "bold":
                    styledFont = NSFont.boldSystemFont(ofSize: defaultFont.pointSize)
                case "italic":
                    styledFont = NSFont.systemFont(ofSize: defaultFont.pointSize, weight: .light).with(traits: .italic)
                case "code":
                    styledFont = monospacedFont as? NSFont ?? defaultFont
                default:
                    styledFont = defaultFont
                }

                replacement.addAttribute(.font, value: styledFont, range: NSRange(location: 0, length: replacement.length))
                #endif

                // Apply text color
                replacement.addAttribute(.foregroundColor, value: textColor.native, range: NSRange(location: 0, length: replacement.length))

                // Replace the entire match with the styled clean content
                attributedString.replaceCharacters(in: matchRange, with: replacement)
            }
        } catch {
            logger.error("\(fontStyle) regex error: \(error.localizedDescription)")
        }
    }

    // Process and replace markdown links with styled text
    private func processLinksAndReplace(in attributedString: NSMutableAttributedString, textColor: Color) {
        let text = attributedString.string
        let linkPattern = "\\[([^\\]]+)\\]\\(([^\\)]+)\\)"

        do {
            let regex = try NSRegularExpression(pattern: linkPattern, options: [])
            let nsRange = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, range: nsRange)

            // Process from the end to avoid range issues
            for match in matches.reversed() {
                if match.numberOfRanges < 3 { continue }

                let fullRange = match.range
                let textRange = match.range(at: 1)
                _ = match.range(at: 2) // url range

                guard
                    let textRangeInString = Range(textRange, in: text)
                else { continue }

                let linkText = String(text[textRangeInString])

                // Create replacement with just the link text
                let replacement = NSMutableAttributedString(string: linkText)

                #if os(iOS)
                let defaultFont = UIFont.preferredFont(forTextStyle: .body)
                #elseif os(macOS)
                let defaultFont = NSFont.preferredFont(forTextStyle: .body)
                #endif

                // Apply styling
                replacement.addAttribute(.font, value: defaultFont, range: NSRange(location: 0, length: replacement.length))
                replacement.addAttribute(.foregroundColor, value: textColor.native, range: NSRange(location: 0, length: replacement.length))
                replacement.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: replacement.length))

                // Replace the full [text](url) with styled text
                attributedString.replaceCharacters(in: fullRange, with: replacement)
            }
        } catch {
            logger.error("Link regex error: \(error.localizedDescription)")
        }
    }

    // Convert dash bullet points to dot bullet points
    private func convertDashesToDots(_ text: String) -> String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let processedLines = lines.map { line -> String in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.starts(with: "- ") {
                let leadingWhitespace = String(line.prefix(while: { $0.isWhitespace }))
                return leadingWhitespace + "• " + String(trimmed.dropFirst(2))
            }
            return String(line)
        }
        return processedLines.joined(separator: "\n")
    }
}
