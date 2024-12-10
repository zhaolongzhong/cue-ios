import Foundation

#if os(macOS)
extension MCPServerManager {

    func testServers() async {
        print("\n📱 Testing MCP servers...")

        await testFileSystem()
    }

    func testFileSystem() async {
        if let filesystemServer = servers["filesystem"], filesystemServer.isRunning {
            do {
                print("📝 Testing filesystem...")
                let result = try await callToolWithResult(
                    "filesystem",
                    name: "list_allowed_directories",
                    arguments: [:]
                )

                for content in result.content {
                    switch content {
                    case .text(let textContent):
                        print("✅ Filesystem testing result: \(textContent.text)")
                    case .image:
                        break
                    }
                }

                if result.isError {
                    print("❌ Tool returned an error: \(result.content)")
                }
            } catch {
                print("❌ Error executing tool: \(error)")
            }
        }
    }
}

#endif
