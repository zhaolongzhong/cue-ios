import Foundation
import OSLog

public struct MCP {}

#if os(macOS)
// MARK: - Server Context
@MainActor
public class ServerContext {
    let process: Process
    let serverName: String
    let inputPipe: Pipe
    let outputPipe: Pipe
    let errorPipe: Pipe
    var isRunning: Bool
    var outputBuffer: String

    init(process: Process, serverName: String, inputPipe: Pipe, outputPipe: Pipe, errorPipe: Pipe) {
        self.process = process
        self.serverName = serverName
        self.inputPipe = inputPipe
        self.outputPipe = outputPipe
        self.errorPipe = errorPipe
        self.isRunning = false
        self.outputBuffer = ""
    }
}

// MARK: - Server Manager
@MainActor @Observable public class MCPServerManager {
    public var serverTools: [String: [MCPTool]] = [:]
    public private(set) var servers: [String: ServerContext] = [:]
    public private(set) var serverStatuses: [String: Bool] = [:]
    private var isInitialized = false
    private let configManager: ConfigManager
    let logger = Logger(subsystem: "MCP", category: "mcp")

    let configPath: String

    public init() {
        self.configManager = ConfigManager.shared
        self.configPath = configManager.getConfigPath() ?? ""
        logger.debug("📱 MCPServerManager initialized with config path: \(self.configPath)")
    }

    private func initializeServer(_ serverContext: ServerContext) async throws {
        print("📱 Starting initialization sequence for \(serverContext.serverName)")

        // Send initialize request
        let initRequest = [
            "jsonrpc": "2.0",
            "id": 0,
            "method": "initialize",
            "params": [
                "protocolVersion": "0.1.0",
                "capabilities": [
                    "roots": [
                        "listChanged": true
                    ]
                ],
                "clientInfo": [
                    "name": "cue-app",
                    "version": "1.0.0"
                ]
            ]
        ] as [String: Any]

        let res = try await callTool(server: serverContext.serverName, request: initRequest)
        print("\n📱 Initialize response: \(String(describing: res.prettyPrinted()))")

        // Send initialized notification
        let initializedNotification = [
            "jsonrpc": "2.0",
            "method": "notifications/initialized"
        ] as [String: Any]

        // Write notification
        if let jsonData = try? JSONSerialization.data(withJSONObject: initializedNotification),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            serverContext.inputPipe.fileHandleForWriting.write((jsonString + "\n").data(using: .utf8)!)
        }

        print("📱 Sent initialized notification")

        let listTools = try? await listServerTools(serverContext.serverName)
        serverTools[serverContext.serverName] = listTools

    }

    private func startServer(_ serverName: String, config: MCPServerConfig) throws {
        logger.debug("\n📱 Starting server: \(serverName)")
        logger.debug("   🔹 Command: \(config.command)")
        logger.debug("   🔹 Args: \(config.args)")

        let process = Process()

        do {
            // Set up process
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [config.command] + config.args

            // Set up environment
            var environment = ProcessInfo.processInfo.environment
            if let env = config.env {
                env.forEach { environment[$0] = $1 }
            }

            // Ensure PATH includes Homebrew
            environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:" + (environment["PATH"] ?? "")
            environment["HOME"] = NSHomeDirectory()

            // Critical environment variables for MCP transport
            environment["UV_USE_STDIO"] = "1"
            environment["MCP_TRANSPORT"] = "stdio"
            environment["PYTHONUNBUFFERED"] = "1"
            environment["PORT"] = "0"

            process.environment = environment

            // Set up pipes
            let inputPipe = Pipe()
            let outputPipe = Pipe()
            let errorPipe = Pipe()

            process.standardInput = inputPipe
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            // Ensure pipes stay open
            inputPipe.fileHandleForWriting.writeabilityHandler = { _ in
                // Keep pipe open
            }

            let context = ServerContext(
                process: process,
                serverName: serverName,
                inputPipe: inputPipe,
                outputPipe: outputPipe,
                errorPipe: errorPipe
            )

            // Start the process
            try process.run()

            // Initialize server
            Task {
                do {
                    try await initializeServer(context)
                    context.isRunning = true
                    serverStatuses[serverName] = true
                    print("✅ Server \(serverName) initialized successfully")
                } catch {
                    print("❌ Failed to initialize server \(serverName): \(error)")
                    context.isRunning = false
                    serverStatuses[serverName] = false
                }
            }

            servers[serverName] = context

            // Handle standard output
            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    if let output = String(data: data, encoding: .utf8) {
                        Task { @MainActor in
                            context.outputBuffer += output
                            print("🔵 \(serverName) output: \(output)")
                        }
                    }
                }
            }

            // Handle error output
            errorPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                        if output.contains("Error:") || output.contains("error:") {
                            print("🔴 \(serverName) error: \(output)")
                        } else {
                            print("ℹ️ \(serverName) info: \(output)")
                        }
                    }
                }
            }

            process.terminationHandler = { [weak self] process in
                Task { @MainActor [weak self] in
                    print("⚠️ Server \(serverName) terminated with status: \(process.terminationStatus)")
                    self?.servers[serverName]?.isRunning = false
                    self?.serverStatuses[serverName] = false
                }
            }

        } catch {
            print("❌ Failed to start server \(serverName): \(error)")
            servers.removeValue(forKey: serverName)
            serverStatuses[serverName] = false
            throw MCPServerError.serverInitializationFailed(serverName, error)
        }
    }

    public func startAll() async throws {
        print("\n📱 Starting all servers...")

        if isInitialized {
            print("⚠️ Servers already initialized, stopping first")
            stopAll()
        }

        let config = try loadConfig()
        print("📱 Loaded configuration with \(config.mcpServers.count) servers")

        for (serverName, serverConfig) in config.mcpServers {
            do {
                try startServer(serverName, config: serverConfig)
                // Add small delay between server starts
                try await Task.sleep(nanoseconds: 1_000_000_000)
            } catch {
                print("❌ Failed to start server \(serverName): \(error)")
                continue
            }
        }

        isInitialized = true
        print("✅ All servers started")
    }

    public func stopAll() {
        print("\n📱 Stopping all servers...")
        for (serverName, context) in servers {
            print("📱 Stopping server: \(serverName)")
            context.process.terminate()
            print("✅ Server \(serverName) stopped")
        }
        servers.removeAll()
        serverStatuses.removeAll()
        isInitialized = false
        print("✅ All servers stopped")
    }

    deinit {
        print("📱 MCPServerManager being deinitialized")
        Task { @MainActor [weak self] in
            guard let self = self else { return }

            // First terminate all processes
            for (serverName, context) in self.servers {
                print("📱 Stopping server: \(serverName)")
                context.process.terminate()

                // Clean up pipes
                context.inputPipe.fileHandleForWriting.writeabilityHandler = nil
                context.outputPipe.fileHandleForReading.readabilityHandler = nil
                context.errorPipe.fileHandleForReading.readabilityHandler = nil

                print("✅ Server \(serverName) stopped")
            }

            // Then clean up state
            self.servers.removeAll()
            self.serverStatuses.removeAll()
            self.isInitialized = false
            print("✅ All servers stopped")
        }
    }
}

#endif
