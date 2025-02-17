import SwiftUI

struct CleanEmailMessage: Sendable {
    let id: String
    let subject: String
    let from: String
    let snippet: String
    let content: String
    let date: String
    let labelIds: [String]
}

extension CleanEmailMessage {
    // Initialize from a raw GmailMessage by extracting header values.
    init(from gmailMessage: GmailMessage) {
        self.id = gmailMessage.id
        self.snippet = gmailMessage.snippet ?? "[No snippet]"
        self.content = extractEmailBody(from: gmailMessage)
        let headers = gmailMessage.payload?.headers
        self.subject = getHeaderValue(headers, key: "Subject") ?? "[No subject]"
        self.from = getHeaderValue(headers, key: "From") ?? "[No sender]"
        self.date = getHeaderValue(headers, key: "Date") ?? "[No date]"
        self.labelIds = gmailMessage.labelIds ?? []
    }
}

// Update toString to use cleaned content
extension CleanEmailMessage {
    func toString(includeContent: Bool = false) -> String {
        if includeContent {
            let startTime = DispatchTime.now()  // Start time
            var content = self.cleanContent()

            let endTime = DispatchTime.now()    // End time
            let duration = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000  // Convert to seconds

            print("cleanContent() took \(duration) seconds")
            let maxLength = 2000
            let truncationSuffix = "[truncated]"
            let originalCount = content.count

            print("Content length: \(content.count), Preview: \(content.prefix(100))...")

            if content.count > maxLength {
                // Find the last space before maxLength to avoid cutting words
                if let spaceIndex = content[..<content.index(content.startIndex, offsetBy: min(maxLength, content.count))]
                    .lastIndex(of: " ") {
                    content = String(content[..<spaceIndex]) + truncationSuffix
                } else {
                    // Fallback if no space found
                    content = String(content.prefix(maxLength)) + truncationSuffix
                }
                print("WARNING: Content truncated to \(content.count) characters, original: \(originalCount)")
            }

            return """
            ID: \(self.id)
            Subject: \(self.subject)
            From: \(self.from)
            Date: \(self.date)
            LabelIds: \(self.labelIds.joined(separator: ", "))
            Snippet: \(self.snippet)
            Content: \(content)
            """
        } else {
            return """
            ID: \(self.id)
            Subject: \(self.subject)
            From: \(self.from)
            Date: \(self.date)
            LabelIds: \(self.labelIds.joined(separator: ", "))
            Snippet: \(self.snippet)
            """
        }
    }
}
extension CleanEmailMessage {
    // Pre-compile regex patterns for better performance
    private static let compiledPatterns: [NSRegularExpression] = {
        let patterns = [
            // Combined style patterns
            #"(?:@media[^{]+\{[^}]+\}|style=\"[^\"]+\"|\.[a-zA-Z_-]+\s*\{[^}]+\}|\*\[class\][^}]+\})"#,

            // Combined footer and social patterns
            #"(?i)(?:follow suggestions?:|view profile|facebook|instagram|linkedin|youtube|unsubscribe|manage preferences|privacy|log in|investment and insurance products:|stay up-to-date).*$"#,

            // Combined URL patterns
            #"(?:https?:\/\/[^\s)>]+|https?:\\\/\\\/[^\s)>]+|\([^\)]*?https?:\/\/[^\)]+\)|\([^\)]*?https?:\\\/\\\/[^\)]+\)|<[^>]*?https?:\/\/[^>]+>|<[^>]*?https?:\\\/\\\/[^>]+>|https?:\/\/[^\s)>\r\n]+[\r\n]*|https?:\\\/\\\/[^\s)>\r\n]+[\r\n]*|\([^\)]*?https?:\/\/[^\)]+[\r\n]+[^\)]*?\)|Keep reading on \w+\s*https?:\/\/[^\s]+|Read (?:this |on |more on )?\w+:?\s*https?:\/\/[^\s]+|Learn (?:more|why)[^:]*:\s*https?:\/\/[^\s]+|[^\s:]+:\s*https?:\/\/[^\s]+)"#,

            // Combined separator patterns
            #"[-=_]{3,}|[-=_\s]{3,}|\*{3,}|#{3,}"#,

            // Combined HTML cleanup
            #"(?:<[^>]+>|&nbsp;|&amp;|&lt;|&gt;|&quot;|&apos;|&zwnj;|\\r|\\n)"#,

            // Combined noise patterns
            #"(?:\(\s*\)|^\s*\d+\s*$|\b\d{1,3}K?\b(?:\s+followers?)?|=%%\".*?>|\s+'|other'\)=)"#,

            // Combined whitespace patterns
            #"\s{2,}|(\r?\n\s*){2,}"#
        ]

        return patterns.compactMap { pattern in
            try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
        }
    }()

    func cleanContent() -> String {
        var cleanedContent = self.content

        // Quick check for empty or simple content
        guard !cleanedContent.isEmpty && cleanedContent.count > 10 else {
            return cleanedContent
        }

        // Handle tables first if needed
        if cleanedContent.contains("dataframe") {
            cleanedContent = cleanTableData(cleanedContent)
        }

        // Create a mutable string for faster replacements
        let mutableStr = NSMutableString(string: cleanedContent)

        // Apply all compiled patterns
        for regex in Self.compiledPatterns {
            regex.replaceMatches(
                in: mutableStr,
                range: NSRange(location: 0, length: mutableStr.length),
                withTemplate: " "
            )
        }

        // Convert back to String and perform final cleanup
        cleanedContent = String(mutableStr)
        cleanedContent = cleanedContent.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespaces)

        return cleanedContent
    }

    private func cleanTableData(_ content: String) -> String {
        guard let tableRegex = try? NSRegularExpression(pattern: "(?s)<table.*?</table>") else {
            return content
        }

        var result = content
        let range = NSRange(location: 0, length: content.count)
        let matches = tableRegex.matches(in: content, range: range)

        // Process matches in reverse order to maintain correct indices
        for match in matches.reversed() {
            if let range = Range(match.range, in: content) {
                let tableHtml = String(content[range])
                let formattedTable = formatTableData(tableHtml: tableHtml)
                result = result.replacingCharacters(in: range, with: formattedTable)
            }
        }

        return result
    }

    private func formatTableData(tableHtml: String) -> String {
        let headerPattern = "(?<=<th>).*?(?=</th>)"
        let dataPattern = "(?<=<td>).*?(?=</td>)"

        let headers = matches(for: headerPattern, in: tableHtml)
        let data = matches(for: dataPattern, in: tableHtml)

        guard !headers.isEmpty else { return "" }

        let columnsCount = headers.count
        let headerRow = headers.joined(separator: " | ")
        let separator = String(repeating: "-", count: headerRow.count)

        let rows = stride(from: 0, to: data.count, by: columnsCount).map { i -> String in
            let endIndex = min(i + columnsCount, data.count)
            return Array(data[i..<endIndex]).joined(separator: " | ")
        }

        return ([headerRow, separator] + rows).joined(separator: "\n")
    }

    private func matches(for pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).map {
            String(text[Range($0.range, in: text)!])
        }
    }
}
