import Foundation

@MainActor
extension AnthropicHTTPClient {

    /// Stream events from the Anthropic API
    /// - Parameters:
    ///   - endpoint: The API endpoint to call
    ///   - method: HTTP method (GET, POST, etc.)
    ///   - body: The request body to send
    /// - Returns: A tuple with event stream, connection state stream, and cancel function
    public func stream(
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
                request.setValue(configuration.apiKey, forHTTPHeaderField: "x-api-key")
                request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

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

                // Start the connection
                let (bytes, response) = try await session.bytes(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    log.error("Invalid response - not HTTPURLResponse")
                    throw Anthropic.Error.invalidResponse
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
                eventsContinuation.finish()
            } catch {
                log.error("Stream error: \(error)")
                stateContinuation.yield(.disconnected(error))
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
        log.debug("HTTP error status: \(httpResponse.statusCode)")
        var errorData = Data()
        for try await byte in bytes {
            errorData.append(byte)
        }

        if let apiError = try? JSONDecoder().decode(Anthropic.APIError.self, from: errorData) {
            let errorEvent = ServerStreamingEvent.ErrorEvent(
                id: UUID().uuidString,
                error: apiError.error
            )
            continuation.yield(.error(errorEvent))
            throw Anthropic.Error.apiError(apiError)
        } else {
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            let errorDetails = Anthropic.APIError.ErrorDetails(
                message: errorMessage,
                type: "http_error"
            )
            let errorEvent = ServerStreamingEvent.ErrorEvent(
                id: UUID().uuidString,
                error: errorDetails
            )
            continuation.yield(.error(errorEvent))
            throw Anthropic.Error.unexpectedAPIResponse(errorMessage)
        }
    }

    private func processStreamBytes(
        bytes: URLSession.AsyncBytes,
        continuation: AsyncThrowingStream<ServerStreamingEvent, Error>.Continuation
    ) async throws {
        var buffer = ""
        var currentEvent: String?
        var currentData: String?

        for try await byte in bytes {
            guard let char = String(bytes: [byte], encoding: .utf8) else {
                continue
            }

            buffer += char

            if char != "\n" {
                continue
            }

            let line = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
            buffer = ""

            if line.isEmpty {
                if let eventName = currentEvent, let data = currentData, !data.isEmpty {
                    try await processEventData(eventName: eventName, data: data, continuation: continuation)
                }

                currentEvent = nil
                currentData = nil
            } else if line.hasPrefix("event:") {
                currentEvent = line.replacingOccurrences(of: "event:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            } else if line.hasPrefix("data:") {
                let dataContent = line.replacingOccurrences(of: "data:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                if currentData == nil {
                    currentData = dataContent
                } else {
                    currentData! += dataContent
                }
            }
        }
    }

    private func processEventData(
        eventName: String,
        data: String,
        continuation: AsyncThrowingStream<ServerStreamingEvent, Error>.Continuation
    ) async throws {
        guard let jsonData = data.data(using: .utf8) else {
            return
        }

        // Create a valid JSON object with the event type
        var jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] ?? [:]
        jsonObject["type"] = eventName

        let eventJsonData = try JSONSerialization.data(withJSONObject: jsonObject)

        do {
            let event = try JSONDecoder().decode(ServerStreamingEvent.self, from: eventJsonData)
            continuation.yield(event)
        } catch {
            log.error("Error decoding \(eventName) event: \(error)")

            // Create an error event when decoding fails
            let errorDetails = Anthropic.APIError.ErrorDetails(
                message: "Failed to decode event: \(error.localizedDescription)",
                type: "decoding_error"
            )
            let errorEvent = ServerStreamingEvent.ErrorEvent(
                id: UUID().uuidString,
                error: errorDetails
            )
            continuation.yield(.error(errorEvent))
        }
    }

    // MARK: - Convenience Methods

    /// Stream a message from the Anthropic API
    /// - Parameter request: The message request containing prompt and parameters
    /// - Returns: A tuple with event stream, connection state stream, and cancel function
    public func streamMessage(request: Anthropic.MessageRequest) -> (
        events: AsyncThrowingStream<ServerStreamingEvent, Error>,
        connectionState: AsyncStream<ServerStreamingEvent.ConnectionState>,
        cancel: () -> Void
    ) {
        return stream(
            endpoint: "messages",
            method: "POST",
            body: request
        )
    }
}
