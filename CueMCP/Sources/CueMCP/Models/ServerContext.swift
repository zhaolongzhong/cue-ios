//
//  ServerContext.swift
//  CueMCP
//

import Foundation

#if os(macOS)
public struct ServerContext: Equatable, Sendable {
    public let serverName: String
    let process: Process
    let inputPipe: Pipe
    let outputPipe: Pipe
    let errorPipe: Pipe
    let isRunning: Bool
    let outputBuffer: String

    init(process: Process, serverName: String, inputPipe: Pipe, outputPipe: Pipe, errorPipe: Pipe) {
        self.process = process
        self.serverName = serverName
        self.inputPipe = inputPipe
        self.outputPipe = outputPipe
        self.errorPipe = errorPipe
        self.isRunning = false
        self.outputBuffer = ""
    }

    private init(
        process: Process,
        serverName: String,
        inputPipe: Pipe,
        outputPipe: Pipe,
        errorPipe: Pipe,
        isRunning: Bool,
        outputBuffer: String
    ) {
        self.process = process
        self.serverName = serverName
        self.inputPipe = inputPipe
        self.outputPipe = outputPipe
        self.errorPipe = errorPipe
        self.isRunning = isRunning
        self.outputBuffer = outputBuffer
    }

    // MARK: - Copying with updates

    /// Creates a copy with updated properties
    public func copy(
        serverName: String? = nil,
        process: Process? = nil,
        inputPipe: Pipe? = nil,
        outputPipe: Pipe? = nil,
        errorPipe: Pipe? = nil,
        isRunning: Bool? = nil,
        outputBuffer: String? = nil
    ) -> ServerContext {
        return ServerContext(
            process: process ?? self.process,
            serverName: serverName ?? self.serverName,
            inputPipe: inputPipe ?? self.inputPipe,
            outputPipe: outputPipe ?? self.outputPipe,
            errorPipe: errorPipe ?? self.errorPipe,
            isRunning: isRunning ?? self.isRunning,
            outputBuffer: outputBuffer ?? self.outputBuffer
        )
    }

    // MARK: - Convenience method for appending to outputBuffer

    /// Returns a new ServerContext with appended content to the outputBuffer
    public func appendingOutput(_ content: String) -> ServerContext {
        copy(outputBuffer: outputBuffer + content)
    }
}
#endif
