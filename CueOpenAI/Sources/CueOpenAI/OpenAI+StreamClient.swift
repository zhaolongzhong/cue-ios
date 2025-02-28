import Foundation

@MainActor
extension OpenAIClient {
    func stream(
        endpoint: String,
        method: String,
        body: Encodable,
        delegate: OpenAI.StreamingDelegate
    ) async throws -> Task<Void, Error> {
        let url = configuration.baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        let bodyData = try encoder.encode(body)
        var bodyDict = try JSONSerialization.jsonObject(
            with: bodyData,
            options: []
        ) as? [String: Any] ?? [:]

        bodyDict["stream"] = true

        let finalBodyData = try JSONSerialization.data(withJSONObject: bodyDict)
        request.httpBody = finalBodyData

        let task = Task {
            let (bytes, response) = try await session.bytes(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                log.error("DEBUG-STREAM: Invalid response - not HTTPURLResponse")
                throw OpenAI.Error.invalidResponse
            }

            if !(200...299).contains(httpResponse.statusCode) {
                try await handleHttpError(bytes: bytes, httpResponse: httpResponse)
            }

            try await processStreamBytes(bytes: bytes, delegate: delegate)
        }
        return task
    }

    private func handleHttpError(bytes: URLSession.AsyncBytes, httpResponse: HTTPURLResponse) async throws {
        log.debug("DEBUG-STREAM: HTTP error status: \(httpResponse.statusCode)")
        var errorData = Data()
        for try await byte in bytes {
            errorData.append(byte)
        }

        if let apiError = try? JSONDecoder().decode(OpenAI.APIError.self, from: errorData) {
            throw OpenAI.Error.apiError(apiError)
        } else {
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw OpenAI.Error.unexpectedAPIResponse(errorMessage)
        }
    }

    func processStreamBytes(bytes: URLSession.AsyncBytes, delegate: OpenAI.StreamingDelegate) async throws {
        var buffer = ""
        let decoder = JSONDecoder()
        for try await byte in bytes {
            guard let char = String(bytes: [byte], encoding: .utf8) else {
                continue
            }

            buffer += char

            // Process each complete message (ends with newline)
            if buffer.contains("\n") {
                let lines = buffer.components(separatedBy: "\n")
                buffer = lines.last ?? ""

                for line in lines.dropLast() {
                    if line.isEmpty { continue }


                    // Remove the "data: " prefix if it exists
                    var jsonLine = line
                    if jsonLine.hasPrefix("data: ") {
                        jsonLine = String(jsonLine.dropFirst(6))
                    }

                    if jsonLine.trimmingCharacters(in: .whitespacesAndNewlines) == "[DONE]" {
                        print("Receive [DONE], stream completed")
                        continue
                    }

                    do {
                        guard let jsonData = jsonLine.data(using: .utf8) else { continue }
                        let chunk = try decoder.decode(OpenAI.ChatCompletionChunk.self, from: jsonData)
                        for choice in chunk.choices {
                            if let role = choice.delta.role, !role.isEmpty {
                                Task {
                                    await delegate.didReceiveStart(id: chunk.id, model: chunk.model)
                                }
                            }

                            // Content delta
                            if let content = choice.delta.content, !content.isEmpty {
                                Task {
                                    await delegate.didReceiveContent(id: chunk.id, delta: content, index: choice.index)
                                }
                            }

                            // Tool calls delta
                            if let toolCalls = choice.delta.toolCalls, !toolCalls.isEmpty {
                                Task {
                                    await delegate.didReceiveToolCallDelta(id: chunk.id, delta: toolCalls, index: choice.index)
                                }
                            }

                            // Check for finish reason
                            if let finishReason = choice.finishReason {
                                Task {
                                    await delegate.didReceiveStop(id: chunk.id, finishReason: finishReason, index: choice.index)
                                }
                            }
                        }
                    } catch {
                        log.error("Error decoding chunk: \(error)")
                        Task {
                            await delegate.didReceiveError(OpenAI.Error.decodingError(error as? DecodingError ?? DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: error.localizedDescription))))
                        }
                    }
                }
            }
        }

    }
}
