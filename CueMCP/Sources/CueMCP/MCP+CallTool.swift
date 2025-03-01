import Foundation
import CueCommon

#if os(macOS)
extension MCPServerManager {

    func callTool(server: String, request: [String: Any], timeout: UInt64 = 5_000_000_000) async throws -> JSONValue {
        guard let serverContext = servers[server] else {
            throw MCPServerError.serverNotFound(server)
        }

        return try await withCheckedThrowingContinuation { continuation in
            actor ResponseState {
                private var hasResumed = false
                private var buffer: String = ""

                func append(_ string: String) {
                    buffer += string
                }

                func getCurrentBuffer() -> String {
                    return buffer
                }

                func updateBuffer(from range: String.Index) {
                    buffer = String(buffer[range...])
                }

                func tryResume(with continuation: CheckedContinuation<JSONValue, Error>, result: Result<JSONValue, Error>) -> Bool {
                    if !hasResumed {
                        hasResumed = true
                        switch result {
                        case .success(let value):
                            continuation.resume(returning: value)
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                        return true
                    }
                    return false
                }
            }

            let state = ResponseState()

            do {
                let jsonData = try JSONSerialization.data(withJSONObject: request)
                let jsonString = String(data: jsonData, encoding: .utf8)! + "\n"

                print("📤 Sending request to \(server): \(jsonString)")

                // Set up response handler before sending request
                serverContext.outputPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty else { return }

                    Task {
                        if let chunk = String(data: data, encoding: .utf8) {
                            // print("📥 Received chunk from \(server): \(chunk)")
                            await state.append(chunk)

                            let currentBuffer = await state.getCurrentBuffer()

                            if let range = currentBuffer.range(of: "\n"),
                               let jsonData = currentBuffer[..<range.lowerBound].data(using: .utf8) {
                                do {
                                    let response = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
//                                     print("📥 Parsed response: \(String(describing: response))")

                                    if let result = response?["result"] {
                                        let jsonResult = JSONValue(any: result)
                                        let didResume = await state.tryResume(with: continuation, result: .success(jsonResult))
                                        if didResume {
                                            Task { @MainActor in
                                                serverContext.outputPipe.fileHandleForReading.readabilityHandler = nil
                                            }
                                        }
                                    } else if let error = response?["error"] {
                                        let jsonError = JSONValue(any: error)
                                        let didResume = await state.tryResume(with: continuation, result: .failure(MCPServerError.invalidConfig("Server error: \(jsonError)")))
                                        if didResume {
                                            Task { @MainActor in
                                                serverContext.outputPipe.fileHandleForReading.readabilityHandler = nil
                                            }
                                        }
                                    }

                                    await state.updateBuffer(from: range.upperBound)
                                } catch {
                                    self.logger.error("❌ JSON parse error: \(error)")
                                    let didResume = await state.tryResume(with: continuation, result: .failure(MCPServerError.invalidConfig("JSON parse error: \(error.localizedDescription)")))
                                    if didResume {
                                        Task { @MainActor in
                                            serverContext.outputPipe.fileHandleForReading.readabilityHandler = nil
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Write request after setting up handler
                serverContext.inputPipe.fileHandleForWriting.write(jsonString.data(using: .utf8)!)

                // Set timeout
                Task {
                    try await Task.sleep(nanoseconds: timeout)
                    let finalBuffer = await state.getCurrentBuffer()

                    let didResume = await state.tryResume(with: continuation, result: .failure(MCPServerError.invalidConfig("Request timed out")))
                    if didResume {
                        await MainActor.run {
                            if serverContext.outputPipe.fileHandleForReading.readabilityHandler != nil {
                                print("⚠️ Request to \(server) timed out. Buffer contents: \(finalBuffer)")
                                serverContext.outputPipe.fileHandleForReading.readabilityHandler = nil
                            }
                        }
                    }
                }
            } catch {
                print("❌ Error sending request: \(error)")
                continuation.resume(throwing: error)
            }
        }
    }

    func listServerTools(_ server: String, isDebug: Bool = false) async throws -> [MCPTool] {
        let request = [
            "jsonrpc": "2.0",
            "id": 0,
            "method": "tools/list",
            "params": [:]
        ] as [String: Any]

        let result = try await callTool(server: server, request: request)

        if isDebug {
            print("📊 Raw result: \(result)")
        }
        
        // Directly encode the JSONValue to Data
        let jsonData = try JSONEncoder().encode(result)

        if isDebug, let jsonString = String(data: jsonData, encoding: .utf8) {
            print("📝 JSON to decode: \(jsonString)")
        }

        // Decode with custom error handling
        do {
            let response = try JSONDecoder().decode(ToolsResponse.self, from: jsonData)
            print("📋 Parsed \(response.tools.count) tools for \(server)")
            return response.tools
        } catch {
            print("❌ Decoding error: \(error)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("Missing key: \(key.stringValue), context: \(context.debugDescription)")
                case .typeMismatch(let type, let context):
                    print("Type mismatch: expected \(type), context: \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    print("Value not found: \(type), context: \(context.debugDescription)")
                case .dataCorrupted(let context):
                    print("Data corrupted: \(context.debugDescription)")
                @unknown default:
                    print("Unknown decoding error")
                }
            }
            throw error
        }
    }
}

#endif
