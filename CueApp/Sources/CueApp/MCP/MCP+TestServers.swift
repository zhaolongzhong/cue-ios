import Foundation

#if os(macOS)
extension MCPServerManager {

    func testServers() async {
        print("\n📱 Testing MCP servers...")

        await testFileSystem()
        // Wait a bit before trying git
        try? await Task.sleep(nanoseconds: 2_000_000_000)

//        await testGit()
    }

    func testFileSystem() async {
        // Test filesystem server
        if let filesystemServer = servers["filesystem"], filesystemServer.isRunning {
            do {
                print("📝 Testing filesystem...")
                let result = try await callToolWithResult(
                    "filesystem",
                    name: "list_allowed_directories",
                    arguments: [:]
                )

                // Access typed content
                for content in result.content {
                    switch content {
                    case .text(let textContent):
                        print("✅ Filesystem testing result: \(textContent.text)")
                    case .image:
                        break
                    }
                }

                // Check for errors
                if result.isError {
                    print("❌ Tool returned an error: \(result.content)")
                }
            } catch {
                print("❌  Error executing tool: \(error)")
            }
        }
    }

//    func testGit() async {
//        // Test git server
//        if let gitServer = servers["git"], gitServer.isRunning {
//
//            do {
//                let result = try await callToolWithResult(
//                    "git",
//                    name: "git_status",
//                    arguments: ["repo_path": "/path/to/repo"]
//                )
//
//                // Access typed content
//                for content in result.content {
//                    switch content {
//                    case .text(let textContent):
//                        print("✅ git server response: \(textContent.text)")
//                    case .image:
//                        break
//                    }
//                }
//
//                // Check for errors
//                if result.isError {
//                    print("Tool returned an error")
//                }
//            } catch {
//                print("Error executing tool: \(error)")
//            }
//        }
//    }

}

#endif
