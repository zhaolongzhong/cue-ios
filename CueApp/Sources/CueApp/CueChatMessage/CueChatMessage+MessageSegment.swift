import SwiftUI
import CueAnthropic

extension CueChatMessage {
    enum MessageSegment {
        case text(String)
        case code(language: String, code: String)
        case thinking(String)
        case file(FileData)

        var text: String {
            switch self {
            case .text(let text):
                return text
            case .code(language: _, code: let text):
                return text
            case .thinking(let text):
                return text
            case .file:
                return ""
            }
        }

        var isThinking: Bool {
            switch self {
            case .thinking:
                return true
            default:
                return false
            }
        }
    }

    func extractSegments(from text: String, isThinking: Bool = false) -> [MessageSegment] {
        var segments: [MessageSegment] = []
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        var lineIndex = 0

        if isThinking {
            return [.thinking(text)]
        }

        // Process thinking block at the beginning if present
        if let newIndex = processInitialThinkingBlock(lines: lines, startIndex: lineIndex, segments: &segments) {
            lineIndex = newIndex
        }

        // Process remaining lines
        while lineIndex < lines.count {
            lineIndex = processNextSegment(lines: lines, startIndex: lineIndex, segments: &segments)
        }

        return segments
    }

    // Process initial thinking block if present
    private func processInitialThinkingBlock(lines: [Substring], startIndex: Int, segments: inout [MessageSegment]) -> Int? {
        guard startIndex < lines.count else { return nil }

        let line = String(lines[startIndex]).trimmingCharacters(in: .whitespaces)
        guard line.hasPrefix("<think>") else { return nil }

        return extractThinkingBlock(lines: lines, startIndex: startIndex, segments: &segments)
    }

    // Process a single segment starting at the given index
    private func processNextSegment(lines: [Substring], startIndex: Int, segments: inout [MessageSegment]) -> Int {
        let line = String(lines[startIndex])

        if line.hasPrefix("```") {
            return extractCodeBlock(lines: lines, startIndex: startIndex, segments: &segments)
        } else if line.contains("<think>") && line.contains("</think>") {
            return extractInlineThinking(line: line, segments: &segments)
        } else {
            segments.append(.text(line))
            return startIndex + 1
        }
    }

    // Extract a thinking block
    private func extractThinkingBlock(lines: [Substring], startIndex: Int, segments: inout [MessageSegment]) -> Int {
        var thinkLines: [String] = []
        var index = startIndex
        var firstLine = String(lines[index])

        if let range = firstLine.range(of: "<think>") {
            firstLine = String(firstLine[range.upperBound...])
        }

        if firstLine.contains("</think>") {
            if let range = firstLine.range(of: "</think>") {
                let content = String(firstLine[..<range.lowerBound])
                segments.append(.thinking(content))
            }
            return index + 1
        }

        thinkLines.append(firstLine)
        index += 1

        while index < lines.count {
            let currentLine = String(lines[index])
            if currentLine.contains("</think>") {
                if let range = currentLine.range(of: "</think>") {
                    thinkLines.append(String(currentLine[..<range.lowerBound]))
                }
                segments.append(.thinking(thinkLines.joined(separator: "\n")))
                return index + 1
            }

            thinkLines.append(currentLine)
            index += 1
        }

        segments.append(.thinking(thinkLines.joined(separator: "\n")))
        return index
    }

    // Extract an inline thinking segment
    private func extractInlineThinking(line: String, segments: inout [MessageSegment]) -> Int {
        if let startRange = line.range(of: "<think>"),
           let endRange = line.range(of: "</think>") {
            let content = String(line[startRange.upperBound..<endRange.lowerBound])
            segments.append(.thinking(content))
        } else {
            segments.append(.text(line))
        }
        return 1
    }

    // Extract a code block
    private func extractCodeBlock(lines: [Substring], startIndex: Int, segments: inout [MessageSegment]) -> Int {
        let line = String(lines[startIndex])
        let language = line.dropFirst(3).trimmingCharacters(in: .whitespaces)
        var blockLines = [line]
        var index = startIndex + 1

        if language.lowercased() == "markdown" {
            index = extractNestedCodeBlock(lines: lines, startIndex: index, blockLines: &blockLines)
        } else {
            index = extractSimpleCodeBlock(lines: lines, startIndex: index, blockLines: &blockLines)
        }

        segments.append(.code(language: String(language), code: blockLines.joined(separator: "\n")))
        return index
    }

    // Extract a nested code block (markdown)
    private func extractNestedCodeBlock(lines: [Substring], startIndex: Int, blockLines: inout [String]) -> Int {
        var index = startIndex
        var nestedLevel = 1

        while index < lines.count {
            let currentLine = String(lines[index])
            if currentLine.hasPrefix("```") {
                if currentLine.trimmingCharacters(in: .whitespaces) == "```" {
                    nestedLevel -= 1
                    blockLines.append(currentLine)
                    index += 1
                    if nestedLevel == 0 { break }
                } else {
                    nestedLevel += 1
                    blockLines.append(currentLine)
                    index += 1
                }
            } else {
                blockLines.append(currentLine)
                index += 1
            }
        }

        return index
    }

    private func extractSimpleCodeBlock(lines: [Substring], startIndex: Int, blockLines: inout [String]) -> Int {
        var index = startIndex

        while index < lines.count {
            let currentLine = String(lines[index])
            blockLines.append(currentLine)
            index += 1
            if currentLine.hasPrefix("```") && currentLine.trimmingCharacters(in: .whitespaces) == "```" {
                break
            }
        }

        return index
    }
}

extension CueChatMessage {
    var segments: [MessageSegment] {
        var finalSegments: [MessageSegment] = []
        if isUser {
            if case .anthropic(let msg, _, _) = self {
                // Check if we have any content blocks
                if msg.contentBlocks.count > 0 {
                    // Handle the first block
                    let firstBlock = msg.contentBlocks[0]
                    if firstBlock.isText {
                        finalSegments.append(.text(firstBlock.text))
                    }

                    // Process all remaining blocks
                    for i in 1..<msg.contentBlocks.count {
                        let block = msg.contentBlocks[i]
                        if block.isText, let fileData = extractFileData(from: block.text) {
                            finalSegments.append(.file(fileData))
                        }
                    }
                }
            } else if case .gemini(let msg, _, _) = self {
                if msg.modelContent.parts.count > 0 {
                    finalSegments.append(.text(msg.modelContent.parts[0].text ?? ""))
                }
                // Process all parts from index 1 onwards (since we already handled index 0)
                for i in 1..<msg.modelContent.parts.count {
                    let block = msg.modelContent.parts[i]
                    if let text = block.text, let fileData = extractFileData(from: text) {
                        finalSegments.append(.file(fileData))
                    }
                }
            } else if case .openAI(let msg, _, _) = self {
                if msg.contentBlocks.count > 0, case .text(let text) = msg.contentBlocks[0] {
                    finalSegments.append(.text(text))
                }
                for i in 1..<msg.contentBlocks.count {
                    let block = msg.contentBlocks[i]
                    if case .text(let text) = block, let fileData = extractFileData(from: text) {
                        finalSegments.append(.file(fileData))
                    }
                }
            } else {
                switch self.content {
                case .string(let text):
                    finalSegments.append(.text(text))
                case .array(let blocks):
                    for block in blocks {
                        if case .text(let text) = block, let fileData = extractFileData(from: text) {
                            finalSegments.append(.file(fileData))
                        }
                    }
                }
            }
        } else if case .anthropic(let msg, _, let streamingState) = self {
            let contentBlocks: [Anthropic.ContentBlock]
            if let blocks = streamingState?.contentBlocks {
                contentBlocks = blocks
            } else {
                contentBlocks = msg.contentBlocks
            }
            for contentBlock in contentBlocks {
                let newSegments = extractSegments(from: contentBlock.text, isThinking: contentBlock.isThinking)
                finalSegments.append(contentsOf: newSegments)
            }
        } else if case .openAI(let msg, _, let streamingState) = self {
            let content: String
            if let currentContent = streamingState?.content {
                content = currentContent
            } else {
                content = msg.content.contentAsString
            }
            let newSegments = extractSegments(from: content, isThinking: false)
            finalSegments.append(contentsOf: newSegments)
        } else {
            let newSegments = extractSegments(from: self.content.contentAsString)
            finalSegments.append(contentsOf: newSegments)
        }
        return finalSegments
    }
}
