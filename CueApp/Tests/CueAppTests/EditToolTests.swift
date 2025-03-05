//
//  EditToolTests.swift
//  CueApp
//

import Testing
import Foundation
@testable import CueApp

struct EditToolTests {

    // MARK: - View Command Tests

    @Test
    func viewCommand_shouldDisplayFileContent() async throws {
        // Given: A temporary file with known content
        let tempFile = try createTempFile(content: "Line 1\nLine 2\nLine 3\nLine 4\nLine 5")
        let editTool = EditTool()

        // When: We call the tool with view command
        let result = try await editTool.call(ToolArguments([
            "command": "view",
            "path": tempFile.path
        ]))

        // Then: It should return the file content with line numbers
        #expect(result.contains("Line 1"), "Result should contain the file content")
        #expect(result.contains("Line 5"), "Result should contain all lines")
        #expect(result.contains("total lines: 5"), "Result should report correct total lines")
    }

    @Test
    func viewCommand_withRange_shouldDisplaySpecifiedLines() async throws {
        // Given: A temporary file with known content
        let tempFile = try createTempFile(content: "Line 1\nLine 2\nLine 3\nLine 4\nLine 5")
        let editTool = EditTool()

        // When: We call the tool with view command and range [2, 4]
        let result = try await editTool.call(ToolArguments([
            "command": "view",
            "path": tempFile.path,
            "view_range": [2, 4]
        ]))

        // Then: It should return only the specified lines with correct line numbers
        #expect(result.contains("Line 2"), "Result should contain line 2")
        #expect(result.contains("Line 3"), "Result should contain line 3")
        #expect(result.contains("Line 4"), "Result should contain line 4")
        #expect(!result.contains("Line 1"), "Result should not contain line 1")
        #expect(!result.contains("Line 5"), "Result should not contain line 5")
        #expect(result.contains("showing lines 2 to 4"), "Result should show the correct line range")
    }

    @Test
    func viewCommand_withInvalidRange_shouldThrowError() async {
        // Given: A temporary file with known content
        let tempFile = try! createTempFile(content: "Line 1\nLine 2\nLine 3")
        let editTool = EditTool()

        // When/Then: Using an out-of-bounds range should throw an error
        var didThrowError = false
        do {
            _ = try await editTool.call(ToolArguments([
                "command": "view",
                "path": tempFile.path,
                "view_range": [1, 10]  // File only has 3 lines
            ]))
        } catch let error {
            didThrowError = true
            #expect(error is ToolError, "Should throw a ToolError")

            // Just check that the error message contains either "view_range" or "second element"
            let errorMessage = String(describing: error)
            #expect(errorMessage.contains("second element") || errorMessage.contains("view_range"),
                   "Error should mention the view range issue")
        }
        #expect(didThrowError, "Should have thrown an error for invalid range")
    }

    // MARK: - Create Command Tests

    @Test
    func createCommand_shouldCreateNewFile() async throws {
        // Given: A path for a new file
        let tempDir = FileManager.default.temporaryDirectory
        let newFilePath = tempDir.appendingPathComponent(UUID().uuidString).path
        let editTool = EditTool()
        let content = "Test content\nMultiple lines"

        // When: We call the tool with create command
        let result = try await editTool.call(ToolArguments([
            "command": "create",
            "path": newFilePath,
            "file_text": content
        ]))

        // Then: The file should be created with the specified content
        #expect(result.contains("File created successfully"), "Should report success")
        #expect(FileManager.default.fileExists(atPath: newFilePath), "File should exist")

        let fileContent = try String(contentsOfFile: newFilePath, encoding: .utf8)
        #expect(fileContent == content, "File should contain the correct content")

        // Cleanup
        try? FileManager.default.removeItem(atPath: newFilePath)
    }

    @Test
    func createCommand_withExistingFile_shouldThrowError() async {
        // Given: An existing temporary file
        let tempFile = try! createTempFile(content: "Existing content")
        let editTool = EditTool()

        // When/Then: Trying to create an existing file should throw an error
        var didThrowError = false
        do {
            _ = try await editTool.call(ToolArguments([
                "command": "create",
                "path": tempFile.path,
                "file_text": "New content"
            ]))
        } catch let error {
            didThrowError = true
            #expect(error is ToolError, "Should throw a ToolError")
            #expect(String(describing: error).contains("already exists"),
                   "Error should mention file already exists")
        }
        #expect(didThrowError, "Should have thrown an error for existing file")
    }

    // MARK: - String Replace Command Tests

    @Test
    func strReplaceCommand_shouldReplaceString() async throws {
        // Given: A temporary file with content for replacement
        let tempFile = try createTempFile(content: "This is a test string for replacement")
        let editTool = EditTool()

        // When: We call the tool with str_replace command
        let result = try await editTool.call(ToolArguments([
            "command": "str_replace",
            "path": tempFile.path,
            "old_str": "test string",
            "new_str": "modified text"
        ]))

        // Then: The string should be replaced
        #expect(result.contains("Edited file"), "Should report success")

        let updatedContent = try String(contentsOfFile: tempFile.path, encoding: .utf8)
        #expect(updatedContent == "This is a modified text for replacement",
               "File content should be updated with the replacement")
    }

    @Test
    func strReplaceCommand_withNonexistentString_shouldThrowError() async {
        // Given: A temporary file with content
        let tempFile = try! createTempFile(content: "This is a test string")
        let editTool = EditTool()

        // When/Then: Trying to replace a nonexistent string should throw an error
        var didThrowError = false
        do {
            _ = try await editTool.call(ToolArguments([
                "command": "str_replace",
                "path": tempFile.path,
                "old_str": "nonexistent string",
                "new_str": "replacement"
            ]))
        } catch let error {
            didThrowError = true
            #expect(error is ToolError, "Should throw a ToolError")
            #expect(String(describing: error).contains("did not appear"),
                   "Error should mention string not found")
        }
        #expect(didThrowError, "Should have thrown an error for nonexistent string")
    }

    @Test
    func strReplaceCommand_withMultipleOccurrences_shouldThrowError() async {
        // Given: A temporary file with multiple occurrences of a string
        let tempFile = try! createTempFile(content: "test test test")
        let editTool = EditTool()

        // When/Then: Trying to replace a string with multiple occurrences should throw an error
        var didThrowError = false
        do {
            _ = try await editTool.call(ToolArguments([
                "command": "str_replace",
                "path": tempFile.path,
                "old_str": "test",
                "new_str": "replaced"
            ]))
        } catch let error {
            didThrowError = true
            #expect(error is ToolError, "Should throw a ToolError")
            #expect(String(describing: error).contains("Multiple occurrences"),
                   "Error should mention multiple occurrences")
        }
        #expect(didThrowError, "Should have thrown an error for multiple occurrences")
    }

    // MARK: - Insert Command Tests

    @Test
    func insertCommand_shouldInsertAtSpecifiedLine() async throws {
        // Given: A temporary file with line-separated content
        let tempFile = try createTempFile(content: "Line 1\nLine 2\nLine 3")
        let editTool = EditTool()

        // When: We call the tool with insert command to insert at line 2
        let result = try await editTool.call(ToolArguments([
            "command": "insert",
            "path": tempFile.path,
            "insert_line": 2,
            "new_str": "Inserted Line"
        ]))

        // Then: The new line should be inserted at the correct position
        #expect(result.contains("Edited file"), "Should report success")

        let updatedContent = try String(contentsOfFile: tempFile.path, encoding: .utf8)
        let expectedContent = "Line 1\nLine 2\nInserted Line\nLine 3"
        #expect(updatedContent == expectedContent,
               "File content should include the inserted line at the correct position")
    }

    @Test
    func insertCommand_withInvalidLine_shouldThrowError() async {
        // Given: A temporary file with line-separated content
        let tempFile = try! createTempFile(content: "Line 1\nLine 2\nLine 3")
        let editTool = EditTool()

        // When/Then: Trying to insert at an invalid line number should throw an error
        var didThrowError = false
        do {
            _ = try await editTool.call(ToolArguments([
                "command": "insert",
                "path": tempFile.path,
                "insert_line": 10,  // File only has 3 lines
                "new_str": "Inserted Line"
            ]))
        } catch let error {
            didThrowError = true
            #expect(error is ToolError, "Should throw a ToolError")

            // More flexible string matching
            let errorMessage = String(describing: error)
            #expect(errorMessage.contains("insert_line") || errorMessage.contains("range of lines"),
                   "Error should mention issue with insert line")
        }
        #expect(didThrowError, "Should have thrown an error for invalid line number")
    }

    // MARK: - Undo Edit Command Tests

    @Test
    func undoEditCommand_shouldRevertLastEdit() async throws {
        // Given: A temporary file that we modify with str_replace
        let originalContent = "Original content"
        let tempFile = try createTempFile(content: originalContent)
        let editTool = EditTool()

        // First, perform a str_replace operation
        _ = try await editTool.call(ToolArguments([
            "command": "str_replace",
            "path": tempFile.path,
            "old_str": "Original",
            "new_str": "Modified"
        ]))

        // Verify the file was changed
        let modifiedContent = try String(contentsOfFile: tempFile.path, encoding: .utf8)
        #expect(modifiedContent == "Modified content", "File should have been modified")

        // When: We call the tool with undo_edit command
        let result = try await editTool.call(ToolArguments([
            "command": "undo_edit",
            "path": tempFile.path
        ]))

        // Then: The file should be reverted to its original content
        #expect(result.contains("Undid last edit"), "Should report success")

        let restoredContent = try String(contentsOfFile: tempFile.path, encoding: .utf8)
        #expect(restoredContent == originalContent,
               "File content should be restored to the original content")
    }

    @Test
    func undoEditCommand_withNoHistory_shouldThrowError() async {
        // Given: A temporary file with no edit history
        let tempFile = try! createTempFile(content: "Test content")
        let editTool = EditTool()

        // When/Then: Trying to undo without history should throw an error
        var didThrowError = false
        do {
            _ = try await editTool.call(ToolArguments([
                "command": "undo_edit",
                "path": tempFile.path
            ]))
        } catch let error {
            didThrowError = true
            #expect(error is ToolError, "Should throw a ToolError")
            #expect(String(describing: error).contains("No edit history"),
                   "Error should mention no edit history")
        }
        #expect(didThrowError, "Should have thrown an error for no edit history")
    }

    // MARK: - Helper Methods

    private func createTempFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(UUID().uuidString)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
}
