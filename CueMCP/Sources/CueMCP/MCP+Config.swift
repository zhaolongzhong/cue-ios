import Foundation

#if os(macOS)
extension MCPServerManager {

    func loadConfig() throws -> MCPServersConfig {
        print("📱 Attempting to load config from: \(self.configPath)")

        let fileURL = URL(fileURLWithPath: self.configPath)

        // Debug file existence
        let fileExists = FileManager.default.fileExists(atPath: fileURL.path)
        print("📱 Config file exists: \(fileExists)")

        guard fileExists else {
            print("❌ Configuration file not found at: \(self.configPath)")
            throw MCPServerError.configNotFound(self.configPath)
        }

        do {
            let data = try Data(contentsOf: fileURL)
            print("📱 Successfully read config file, size: \(data.count) bytes")

            let config = try JSONDecoder().decode(MCPServersConfig.self, from: data)
            print("📱 Successfully decoded config with \(config.mcpServers.count) servers:")
            for (name, _) in config.mcpServers {
                print("   🔹 Server: \(name)")
            }
            return config
        } catch {
            print("❌ Error loading config: \(error)")
            throw MCPServerError.invalidConfig("Failed to load/parse config: \(error)")
        }
    }

    func verifyCommands() async throws {
        print("📱 Verifying required commands...")

        let commandPaths = [
            "npx": [
                "/opt/homebrew/bin/npx",
                "/usr/local/bin/npx"
            ],
            "uvx": [
                "/opt/homebrew/bin/uvx",
                "/usr/local/bin/uvx"
            ]
        ]

        for (command, paths) in commandPaths {
            var found = false
            for path in paths {
                if FileManager.default.fileExists(atPath: path) {
                    print("✅ Found \(command) at: \(path)")
                    found = true
                    break
                }
            }

            if !found {
                // Try using Process to check
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = ["which", command]

                let pipe = Pipe()
                process.standardOutput = pipe

                try process.run()
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty {
                    print("✅ Found \(command) at: \(path)")
                    found = true
                }
            }

            if !found {
                print("❌ Command \(command) not found in any standard location")

                // Debug additional information
                print("📱 Current PATH: \(ProcessInfo.processInfo.environment["PATH"] ?? "not set")")
                print("📱 Checking command accessibility:")
                let checkProcess = Process()
                checkProcess.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                checkProcess.arguments = ["ls", "-l", "/opt/homebrew/bin/\(command)"]

                let checkPipe = Pipe()
                checkProcess.standardOutput = checkPipe

                try checkProcess.run()
                checkProcess.waitUntilExit()

                let checkData = checkPipe.fileHandleForReading.readDataToEndOfFile()
                if let checkOutput = String(data: checkData, encoding: .utf8) {
                    print("📱 File check output: \(checkOutput)")
                }

                throw MCPServerError.invalidConfig("Required command not found: \(command)")
            }
        }
    }
}
#endif
