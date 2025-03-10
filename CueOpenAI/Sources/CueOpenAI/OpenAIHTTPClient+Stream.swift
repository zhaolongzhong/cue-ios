import Foundation
import CueCommon

@MainActor
extension OpenAIHTTPClient {
    func stream(
        endpoint: String,
        method: String,
        body: Encodable
    ) -> (
        events: AsyncThrowingStream<ServerStreamingEvent, Error>,
        connectionState: AsyncStream<ServerStreamingEvent.ConnectionState>,
        cancel: () -> Void
    ) {
        let (events, eventsContinuation) = AsyncThrowingStream<ServerStreamingEvent, Error>.makeStream()
        let (stateStream, stateContinuation) = AsyncStream<ServerStreamingEvent.ConnectionState>.makeStream()

        stateContinuation.yield(.connecting)

        let task = Task {
            do {
                let url = configuration.baseURL.appendingPathComponent(endpoint)
                var request = URLRequest(url: url)
                request.httpMethod = method
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")

                let encoder = JSONEncoder()
                encoder.keyEncodingStrategy = .convertToSnakeCase

                let bodyData = try encoder.encode(body)
                let bodyDict = try JSONSerialization.jsonObject(
                    with: bodyData,
                    options: []
                ) as? [String: Any] ?? [:]

                let finalBodyData = try JSONSerialization.data(withJSONObject: bodyDict)
                request.httpBody = finalBodyData

                // Start the connection
                let (bytes, response) = try await session.bytes(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    log.error("DEBUG-STREAM: Invalid response - not HTTPURLResponse")
                    throw OpenAI.Error.invalidResponse
                }

                if !(200...299).contains(httpResponse.statusCode) {
                    try await handleHttpError(bytes: bytes, httpResponse: httpResponse, continuation: eventsContinuation)
                    return
                }

                // Successfully connected
                stateContinuation.yield(.connected)

                try await processStreamBytes(bytes: bytes, continuation: eventsContinuation)

                // Stream completed successfully
                stateContinuation.yield(.disconnected(nil))
                eventsContinuation.yield(.completed)
                eventsContinuation.finish()
            } catch {
                log.error("Stream error: \(error)")
                stateContinuation.yield(.disconnected(error))

                if let openAIError = error as? OpenAI.Error {
                    let errorEvent = ServerStreamingEvent.ErrorEvent(id: UUID().uuidString, error: openAIError)
                    eventsContinuation.yield(.error(errorEvent))
                }

                eventsContinuation.finish(throwing: error)
            }
        }

        return (events, stateStream, {
            task.cancel()
            eventsContinuation.finish()
            stateContinuation.finish()
        })
    }

    private func handleHttpError(
        bytes: URLSession.AsyncBytes,
        httpResponse: HTTPURLResponse,
        continuation: AsyncThrowingStream<ServerStreamingEvent, Error>.Continuation
    ) async throws {
        log.debug("DEBUG-STREAM: HTTP error status: \(httpResponse.statusCode)")
        var errorData = Data()
        for try await byte in bytes {
            errorData.append(byte)
        }

        if let apiError = try? JSONDecoder().decode(OpenAI.APIError.self, from: errorData) {
            let openAIError = OpenAI.Error.apiError(apiError)
            let errorEvent = ServerStreamingEvent.ErrorEvent(
                id: UUID().uuidString,
                error: openAIError
            )
            continuation.yield(.error(errorEvent))
            throw openAIError
        } else {
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            let openAIError = OpenAI.Error.unexpectedAPIResponse(errorMessage)
            let errorEvent = ServerStreamingEvent.ErrorEvent(
                id: UUID().uuidString,
                error: openAIError
            )
            continuation.yield(.error(errorEvent))
            throw openAIError
        }
    }

    private func processStreamBytes(
        bytes: URLSession.AsyncBytes,
        continuation: AsyncThrowingStream<ServerStreamingEvent, Error>.Continuation
    ) async throws {
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
                        continue
                    }

                    do {
                        guard let jsonData = jsonLine.data(using: .utf8) else { continue }
                        let chunk = try decoder.decode(OpenAI.ChatCompletionChunk.self, from: jsonData)

                        // Emit raw chunk event
                        continuation.yield(.chunk(chunk))

                    } catch {
                        log.error("Error decoding chunk: \(error)")
                        let openAIError = OpenAI.Error.decodingError(error as? DecodingError ?? DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: error.localizedDescription)))
                        let errorEvent = ServerStreamingEvent.ErrorEvent(id: UUID().uuidString, error: openAIError)
                        continuation.yield(.error(errorEvent))
                    }
                }
            }
        }
    }
}
