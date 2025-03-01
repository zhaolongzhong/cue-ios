import Testing
import Foundation
@testable import CueApp
@testable import CueGemini

struct FunctionDeclarationValidationTests {

    @Test
    func validFunctionDeclaration_shouldPassValidation() async throws {
        // Given: A toolManager and a valid function declaration
        let toolManager = await ToolManager()
        let declaration = FunctionDeclaration(
            name: "read_file",
            description: "Read a file",
            parameters: ["path": Schema(type: .string, description: "File path")]
        )

        // When: We validate the declarations
        let declarations = [declaration]
        let validated = await toolManager.validateFunctionDeclarations(declarations)

        // Then: The valid declaration should pass validation
        #expect(validated.count == 1, "Valid function declaration should pass validation")
        #expect(validated.first?.name == "read_file", "The correct declaration should be preserved")
    }

    @Test
    func objectWithProperties_shouldBeValid() async throws {
        // Given: A function declaration with valid properties
        let toolManager = await ToolManager()
        let declaration = FunctionDeclaration(
            name: "list_allowed_directories",
            description: "Returns the list of directories",
            parameters: ["path": Schema(type: .string, description: "Path to list")]
        )

        // When: We validate the declarations
        let declarations = [declaration]
        let validated = await toolManager.validateFunctionDeclarations(declarations)

        // Then: It should pass validation
        #expect(validated.count == 1, "Function with valid object properties should pass validation")
    }

    @Test
    func realWorldExample_fixedListAllowedDirectories_shouldHaveProperties() async throws {
        // Given: A truly fixed version of the problematic function
        let toolManager = await ToolManager()

        // The fix is to add actual properties, not set to nil
        let declaration = FunctionDeclaration(
            name: "list_allowed_directories",
            description: "Returns the list of directories that this server is allowed to access.",
            parameters: ["verbose": Schema(type: .boolean, description: "Whether to show additional details")]
        )

        // When: We validate the declarations
        let declarations = [declaration]
        let validated = await toolManager.validateFunctionDeclarations(declarations)

        // Then: The fixed declaration should pass validation
        #expect(validated.count == 1, "The fixed list_allowed_directories should pass validation")
    }
}
