//
//  BaseTool.swift
//  CueApp
//

import Foundation
import CueOpenAI

// MARK: - Tool Parameters

struct BashParameters: ToolParameters, Sendable {
    let schema: [String: Property] = [
        "command": Property(
            type: "string",
            description: "The bash command to execute"
        ),
        "restart": Property(
            type: "boolean",
            description: "Whether to restart the bash session before executing the command"
        ),
        "timeout": Property(
            type: "number",
            description: "The maximum time in seconds to wait for command execution"
        )
    ]

    let required: [String] = []
}

// MARK: - Bash Tool

#if os(macOS)
final class BashTool: LocalTool, @unchecked Sendable {
    let name: String = "bash"
    let description: String = "Run bash commands."
    let parameterDefinition: ToolParameters = BashParameters()

    private var session: BashSession?

    init() {}

    func call(_ args: ToolArguments) async throws -> String {
        let command = args.getString("command")
        let restart = args.getBool("restart") ?? false
        let timeout: TimeInterval = args.getDouble("timeout") ?? 30.0

        return try await bash(command: command, restart: restart, timeout: timeout)
    }

    private func bash(command: String?, restart: Bool, timeout: TimeInterval = 30.0) async throws -> String {
        // Create session if it doesn't exist
        if self.session == nil {
            self.session = BashSession(timeout: timeout)
        }

        // Handle restart
        if restart {
            self.session?.stop()
            self.session = BashSession(timeout: timeout)
            try self.session?.start()
            return "tool has been restarted."
        }

        try self.session?.start()

        if let command = command, let session = self.session {
            let result = try await session.run(command)

            if let output = result.output {
                if let error = result.error, !error.isEmpty {
                    return "Output:\n\(output)\n\nError:\n\(error)"
                }
                return output
            } else if let system = result.system {
                return system
            } else if let error = result.error {
                return "Error:\n\(error)"
            }

            return "No output returned"
        } else {
            throw ToolError.invalidArguments("no command provided.")
        }
    }
}

final class BashSession: @unchecked Sendable {
    private var process: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    private let timeout: TimeInterval
    private var timedOut = false
    private var started = false

    init(timeout: TimeInterval = 30.0) {
        self.timeout = timeout
    }

    func start() throws {
        if started {
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = []

        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()

        self.process = process
        self.inputPipe = inputPipe
        self.outputPipe = outputPipe
        self.errorPipe = errorPipe
        self.started = true
    }

    func stop() {
        guard started else {
            return
        }

        process?.terminate()
        process = nil
        inputPipe = nil
        outputPipe = nil
        errorPipe = nil
        started = false
    }

    func run(_ command: String) async throws -> ToolResult {
        guard started, let process = process, process.isRunning else {
            if let process = process, !process.isRunning {
                return ToolResult(
                    output: nil,
                    error: "bash has exited with returncode \(process.terminationStatus)",
                    base64_image: nil,
                    system: "tool must be restarted"
                )
            }
            throw ToolError.invalidState("Session has not started.")
        }

        if timedOut {
            throw ToolError.invalidState("timed out: bash has not returned in \(timeout) seconds and must be restarted")
        }

        // Create a simpler implementation that uses Process.terminationHandler
        return try await withCheckedThrowingContinuation { continuation in
            // Set up a timeout handler
            let timeoutTask = Task {
                do {
                    try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    self.timedOut = true
                    continuation.resume(throwing: ToolError.timeout("Command timed out after \(timeout) seconds"))
                } catch {
                    // Task was cancelled, which is fine
                }
            }

            // Create a new process for this specific command
            let cmdProcess = Process()
            cmdProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
            cmdProcess.arguments = ["-c", command]

            // Set up output and error redirection to files
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            cmdProcess.standardOutput = outputPipe
            cmdProcess.standardError = errorPipe

            // Set up termination handler
            cmdProcess.terminationHandler = { _ in
                // Cancel the timeout task
                timeoutTask.cancel()

                // Read output from pipes
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                let output = String(data: outputData, encoding: .utf8) ?? ""
                let error = String(data: errorData, encoding: .utf8) ?? ""

                print("Command completed with output: \(output)")

                // Return the result
                continuation.resume(returning: CLIResult(
                    output: output,
                    error: error.isEmpty ? nil : error,
                    base64_image: nil,
                    system: nil
                ))
            }

            // Run the command
            do {
                try cmdProcess.run()
            } catch {
                timeoutTask.cancel()
                continuation.resume(throwing: error)
            }
        }
    }
}

#endif
