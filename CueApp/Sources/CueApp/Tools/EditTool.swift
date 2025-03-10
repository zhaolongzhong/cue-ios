//
//  EditTool.swift
//  CueApp
//

import Foundation
import CueOpenAI

// MARK: - Command Type

enum EditCommand: String, CaseIterable {
    case view
    case create
    case strReplace = "str_replace"
    case insert
    case undoEdit = "undo_edit"
}

// MARK: - Constants

private let SNIPPET_LINES: Int = 4
private let MAX_RESPONSE_LEN: Int = 8000
private let TRUNCATED_MESSAGE = "\n... output truncated ...\n"
private let DEBUG_ENABLED = false

// MARK: - Tool Parameters

struct EditParameters: ToolParameters, Sendable {
    let schema: [String: OpenAIParametersProperty] = [
        "command": Property(
            type: "string",
            description: "The operation to perform. Must be one of: 'view', 'create', 'str_replace', 'insert', 'undo_edit'"
        ),
        "path": Property(
            type: "string",
            description: "Absolute path to the target file or directory"
        ),
        "file_text": Property(
            type: "string",
            description: "Content to write when creating a new file. Required for 'create' command"
        ),
        "view_range": Property(
            type: "array",
            description: "Two integers specifying start and end line numbers for viewing file content. Only valid for 'view' command on files. Example: [1, 10]",
            items: Property.PropertyItems(type: "integer")
        ),
        "old_str": Property(
            type: "string",
            description: "String to be replaced. Required for 'str_replace' command"
        ),
        "new_str": Property(
            type: "string",
            description: "Replacement string. Required for 'str_replace' and 'insert' commands"
        ),
        "insert_line": Property(
            type: "integer",
            description: "Line number where text should be inserted. Required for 'insert' command"
        )
    ]

    let required: [String] = ["command", "path"]
}

// MARK: - Edit Tool

#if os(macOS)
final class EditTool: LocalTool, @unchecked Sendable {
    let name: String = "edit"
    let description: String = "Perform file operations like viewing, creating, and editing files in the filesystem."
    let parameterDefinition: ToolParameters = EditParameters()

    private var fileHistory: [String: [String]] = [:]
    private let fileManager = FileManager.default

    private func debug(_ message: @autoclosure () -> String) {
        if DEBUG_ENABLED {
            print("[EditTool Debug] \(message())")
        }
    }

    func call(_ args: ToolArguments) async throws -> String {
        guard let commandString = args.getString("command"),
              let command = EditCommand(rawValue: commandString) else {
            let validCommands = EditCommand.allCases.map { $0.rawValue }.joined(separator: ", ")
            throw ToolError.invalidArguments("Unrecognized command. The allowed commands are: \(validCommands)")
        }

        guard let path = args.getString("path") else {
            throw ToolError.invalidArguments("Parameter 'path' is required")
        }

        // Create URL from path
        let url = URL(fileURLWithPath: path)

        // Validate path
        try validatePath(command: command, url: url)

        // Process command using dedicated command handlers
        switch command {
        case .view:
            let viewRange: [Int]? = args.getArray("view_range") as? [Int]
            return try await handleViewCommand(url: url, viewRange: viewRange)

        case .create:
            return try handleCreateCommand(url: url, args: args)

        case .strReplace:
            return try handleStrReplaceCommand(url: url, args: args)

        case .insert:
            return try handleInsertCommand(url: url, args: args)

        case .undoEdit:
            return try undoEdit(url: url)
        }
    }

    // MARK: - Command Handlers

    private func handleViewCommand(url: URL, viewRange: [Int]?) async throws -> String {
        debug("View command with path: \(url.path), view range: \(String(describing: viewRange))")
        return try await view(url: url, viewRange: viewRange)
    }

    private func handleCreateCommand(url: URL, args: ToolArguments) throws -> String {
        guard let fileText = args.getString("file_text") else {
            throw ToolError.invalidArguments("Parameter 'file_text' is required for command: create")
        }

        // Create parent directories if they don't exist
        try fileManager.createDirectory(at: url.deletingLastPathComponent(),
                                      withIntermediateDirectories: true,
                                      attributes: nil)

        try writeFile(url: url, content: fileText)

        // Save to history
        let key = url.path
        if fileHistory[key] == nil {
            fileHistory[key] = []
        }
        fileHistory[key]?.append(fileText)

        return "File created successfully at: \(url.path)"
    }

    private func handleStrReplaceCommand(url: URL, args: ToolArguments) throws -> String {
        guard let oldStr = args.getString("old_str") else {
            throw ToolError.invalidArguments("Parameter 'old_str' is required for command: str_replace")
        }

        let newStr = args.getString("new_str") ?? ""
        return try strReplace(url: url, oldStr: oldStr, newStr: newStr)
    }

    private func handleInsertCommand(url: URL, args: ToolArguments) throws -> String {
        guard let insertLine = args.getInt("insert_line") else {
            throw ToolError.invalidArguments("Parameter 'insert_line' is required for command: insert")
        }

        guard let newStr = args.getString("new_str") else {
            throw ToolError.invalidArguments("Parameter 'new_str' is required for command: insert")
        }

        return try insert(url: url, insertLine: insertLine, newStr: newStr)
    }

    // MARK: - Private Methods

    private func validatePath(command: EditCommand, url: URL) throws {
        // Check if it's an absolute path
        if !url.path.hasPrefix("/") {
            let suggestedPath = "/" + url.path
            throw ToolError.invalidArguments("The path \(url.path) is not an absolute path, it should start with '/'. Maybe you meant \(suggestedPath)?")
        }

        // Check if path exists (except for create command)
        let exists = fileManager.fileExists(atPath: url.path)
        if !exists && command != .create {
            throw ToolError.invalidArguments("The path \(url.path) does not exist. Please provide a valid path.")
        }

        if exists && command == .create {
            throw ToolError.invalidArguments("File already exists at: \(url.path). Cannot overwrite files using command 'create'.")
        }

        // Check if the path points to a directory
        var isDirectory: ObjCBool = false
        _ = fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)

        if isDirectory.boolValue {
            if command != .view {
                throw ToolError.invalidArguments("The path \(url.path) is a directory and only the 'view' command can be used on directories")
            }
        }
    }

    private func view(url: URL, viewRange: [Int]?) async throws -> String {
        var isDirectory: ObjCBool = false
        fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)

        if isDirectory.boolValue {
            if viewRange != nil {
                throw ToolError.invalidArguments("The 'view_range' parameter is not allowed when 'path' points to a directory.")
            }

            // Use Process to run 'find' command for directories
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/find")
            process.arguments = [url.path, "-maxdepth", "2", "-not", "-path", "*/\\.*"]

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            try process.run()
            process.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

            let output = String(data: outputData, encoding: .utf8) ?? ""
            let error = String(data: errorData, encoding: .utf8) ?? ""

            if error.isEmpty {
                return "Directory listing: \(url.path) (showing files and directories up to 2 levels deep, excluding hidden items):\n\(output)\n"
            } else {
                return CLIResult(output: output, error: error).description
            }
        }

        let fileContent = try readFile(url: url)
        let totalLines = fileContent.components(separatedBy: "\n").count
        debug("File has \(totalLines) total lines, viewRange: \(String(describing: viewRange))")

        if let viewRange = viewRange {
            if viewRange.count != 2 {
                throw ToolError.invalidArguments("Invalid 'view_range'. It should be a list of two integers.")
            }

            let fileLines = fileContent.components(separatedBy: "\n")
            let nLinesFile = fileLines.count
            debug("File has \(nLinesFile) lines")

            let initLineValue = viewRange[0]
            let finalLineValue = viewRange[1]
            debug("Requested view range: [\(initLineValue), \(finalLineValue)]")

            if initLineValue < 1 || initLineValue > nLinesFile {
                throw ToolError.invalidArguments("Invalid 'view_range': \(viewRange). Its first element '\(initLineValue)' should be within the range of lines of the file: [1, \(nLinesFile)]")
            }

            if finalLineValue != -1 && finalLineValue > nLinesFile {
                throw ToolError.invalidArguments("Invalid 'view_range': \(viewRange). Its second element '\(finalLineValue)' should be smaller than the number of lines in the file: '\(nLinesFile)'")
            }

            if finalLineValue != -1 && finalLineValue < initLineValue {
                throw ToolError.invalidArguments("Invalid 'view_range': \(viewRange). Its second element '\(finalLineValue)' should be larger or equal than its first '\(initLineValue)'")
            }

            // Calculate the slice of lines to show
            let startIndex = initLineValue - 1  // Convert to 0-based index
            let endIndex: Int

            if finalLineValue == -1 {
                endIndex = nLinesFile  // All lines to the end
            } else {
                endIndex = finalLineValue  // Up to the specified line (exclusive)
            }

            debug("Slicing from index \(startIndex) to \(endIndex)")

            // Extract only the lines in the requested range
            if startIndex >= fileLines.count {
                debug("Start index is out of bounds")
                throw ToolError.invalidArguments("Invalid 'view_range': startIndex \(startIndex) is out of bounds for array of size \(fileLines.count)")
            }

            let endIndexBounded = min(endIndex, fileLines.count)
            let selectedLines = Array(fileLines[startIndex..<endIndexBounded])
            debug("Selected \(selectedLines.count) lines from the file")

            let resultContent = selectedLines.joined(separator: "\n")

            return makeViewOutput(
                content: resultContent,
                fileDescriptor: url.path,
                initLine: initLineValue,
                totalLines: nLinesFile,
                viewRange: viewRange
            )
        }

        // When no range is specified, return the full file content
        debug("No view range specified, returning all \(totalLines) lines")
        return makeViewOutput(
            content: fileContent,
            fileDescriptor: url.path,
            initLine: 1,
            totalLines: totalLines,
            viewRange: nil
        )
    }

    private func strReplace(url: URL, oldStr: String, newStr: String) throws -> String {
        // Read the file content
        let fileContent = try readFile(url: url).replacingOccurrences(of: "\t", with: "    ")
        let oldStrExpanded = oldStr.replacingOccurrences(of: "\t", with: "    ")
        let newStrExpanded = newStr.replacingOccurrences(of: "\t", with: "    ")

        // Check if oldStr is unique in the file
        let components = fileContent.components(separatedBy: oldStrExpanded)
        let occurrences = components.count - 1
        debug("Found \(occurrences) occurrences of the string to replace")

        if occurrences == 0 {
            throw ToolError.invalidArguments("No replacement was performed, old_str '\(oldStrExpanded)' did not appear verbatim in \(url.path).")
        } else if occurrences > 1 {
            let fileContentLines = fileContent.components(separatedBy: "\n")
            let lines = fileContentLines.enumerated()
                .filter { $0.element.contains(oldStrExpanded) }
                .map { $0.offset + 1 }

            throw ToolError.invalidArguments("No replacement was performed. Multiple occurrences of old_str '\(oldStrExpanded)' in lines \(lines). Please ensure it is unique")
        }

        // Replace oldStr with newStr
        let newFileContent = fileContent.replacingOccurrences(of: oldStrExpanded, with: newStrExpanded)

        // Write the new content to the file
        try writeFile(url: url, content: newFileContent)

        // Save the content to history
        let key = url.path
        if fileHistory[key] == nil {
            fileHistory[key] = []
        }
        fileHistory[key]?.append(fileContent)

        // Create a snippet of the edited section
        let beforeReplacementText = components.first ?? ""
        let replacementLine = beforeReplacementText.components(separatedBy: "\n").count
        debug("Replacement occurs at approximately line \(replacementLine)")

        // Determine snippet range
        let startLine = max(0, replacementLine - SNIPPET_LINES)
        let newFileContentLines = newFileContent.components(separatedBy: "\n")
        let endLine = min(
            replacementLine + SNIPPET_LINES + newStrExpanded.components(separatedBy: "\n").count - 1,
            newFileContentLines.count - 1
        )

        debug("Snippet range: from line \(startLine + 1) to \(endLine + 1)")

        // Extract the snippet
        let safeStartIndex = min(startLine, newFileContentLines.count - 1)
        let safeEndIndex = min(endLine, newFileContentLines.count - 1)

        let snippetLines = Array(newFileContentLines[safeStartIndex...safeEndIndex])
        let snippet = snippetLines.joined(separator: "\n")

        // Prepare the success message
        var successMsg = "Edited file: \(url.path) (replaced '\(oldStrExpanded)' with '\(newStrExpanded)')\n\n"
        successMsg += makeEditOutput(
            content: snippet,
            fileDescriptor: url.path,
            initLine: startLine + 1,
            operation: "str_replace"
        )
        successMsg += "\nReview the changes and make sure they are as expected. Edit the file again if necessary."

        return successMsg
    }

    private func insert(url: URL, insertLine: Int, newStr: String) throws -> String {
        let fileContent = try readFile(url: url).replacingOccurrences(of: "\t", with: "    ")
        let newStrExpanded = newStr.replacingOccurrences(of: "\t", with: "    ")

        let fileTextLines = fileContent.components(separatedBy: "\n")
        let nLinesFile = fileTextLines.count
        debug("File has \(nLinesFile) lines, inserting at line \(insertLine)")

        if insertLine < 0 || insertLine > nLinesFile {
            throw ToolError.invalidArguments("Invalid 'insert_line' parameter: \(insertLine). It should be within the range of lines of the file: [0, \(nLinesFile)]")
        }

        let newStrLines = newStrExpanded.components(separatedBy: "\n")
        debug("Inserting \(newStrLines.count) new lines at position \(insertLine)")

        var newFileTextLines = fileTextLines
        newFileTextLines.insert(contentsOf: newStrLines, at: insertLine)

        // Create snippet showing context around the insertion
        let startSnippetLine = max(0, insertLine - SNIPPET_LINES)
        let endSnippetLine = min(insertLine + SNIPPET_LINES + newStrLines.count, newFileTextLines.count)
        debug("Snippet range: from line \(startSnippetLine + 1) to \(endSnippetLine)")

        // Make sure we're not exceeding array bounds
        let safeStartIndex = min(startSnippetLine, newFileTextLines.count - 1)
        let safeEndIndex = min(endSnippetLine, newFileTextLines.count)

        let snippetLines = Array(newFileTextLines[safeStartIndex..<safeEndIndex])
        let snippet = snippetLines.joined(separator: "\n")
        let newFileText = newFileTextLines.joined(separator: "\n")

        try writeFile(url: url, content: newFileText)

        // Save to history
        let key = url.path
        if fileHistory[key] == nil {
            fileHistory[key] = []
        }
        fileHistory[key]?.append(fileContent)

        var successMsg = "Edited file: \(url.path) (inserted \(newStrLines.count) line(s) at position \(insertLine))\n\n"
        successMsg += makeEditOutput(
            content: snippet,
            fileDescriptor: url.path,
            initLine: max(1, insertLine - SNIPPET_LINES + 1),
            operation: "insert"
        )
        successMsg += "\nReview the changes and make sure they are as expected (correct indentation, no duplicate lines, etc). Edit the file again if necessary."

        return successMsg
    }

    private func undoEdit(url: URL) throws -> String {
        let key = url.path
        guard let history = fileHistory[key], !history.isEmpty else {
            throw ToolError.invalidState("No edit history found for \(url.path).")
        }

        guard let oldText = fileHistory[key]?.popLast() else {
            throw ToolError.invalidState("Failed to retrieve history for \(url.path).")
        }

        try writeFile(url: url, content: oldText)

        let totalLines = oldText.components(separatedBy: "\n").count

        return "Undid last edit to \(url.path). File restored to previous state.\n\n\(makeViewOutput(content: oldText, fileDescriptor: url.path, initLine: 1, totalLines: totalLines, viewRange: nil))"
    }

    private func readFile(url: URL) throws -> String {
        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw ToolError.invalidState("Ran into \(error) while trying to read \(url.path)")
        }
    }

    private func writeFile(url: URL, content: String) throws {
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw ToolError.invalidState("Ran into \(error) while trying to write to \(url.path)")
        }
    }

    private func makeViewOutput(content: String, fileDescriptor: String, initLine: Int, totalLines: Int, viewRange: [Int]?) -> String {
        var header = "File: \(fileDescriptor) (total lines: \(totalLines))"

        if let viewRange = viewRange {
            let endLine = viewRange[1] == -1 ? totalLines : viewRange[1]
            header += " - showing lines \(viewRange[0]) to \(endLine)"
        }

        return header + "\n\n" + makeNumberedContent(content: content, initLine: initLine, expandTabs: true)
    }

    private func makeEditOutput(content: String, fileDescriptor: String, initLine: Int, operation: String) -> String {
        let header = "Snippet of \(fileDescriptor) after \(operation) operation (showing lines \(initLine) to \(initLine + content.components(separatedBy: "\n").count - 1)):"
        return header + "\n\n" + makeNumberedContent(content: content, initLine: initLine, expandTabs: true)
    }

    private func makeNumberedContent(content: String, initLine: Int = 1, expandTabs: Bool = true) -> String {
        // First truncate if needed
        var fileContent = maybeTruncate(content: content)

        // Expand tabs if requested
        if expandTabs {
            fileContent = fileContent.replacingOccurrences(of: "\t", with: "    ")
        }

        // Split into lines, number them starting from initLine
        let lines = fileContent.components(separatedBy: "\n")
        let numberedLines = lines.enumerated().map { line -> String in
            let lineNumber = line.offset + initLine
            return String(format: "%6d | %@", lineNumber, line.element)
        }

        return numberedLines.joined(separator: "\n")
    }

    private func maybeTruncate(content: String, truncateAfter: Int = MAX_RESPONSE_LEN) -> String {
        if truncateAfter > 0 && content.count > truncateAfter {
            let index = content.index(content.startIndex, offsetBy: truncateAfter)
            return String(content[..<index]) + TRUNCATED_MESSAGE
        }
        return content
    }
}
#endif
