import Foundation

@MainActor
extension AnthropicClient {
    func stream(
        endpoint: String,
        method: String,
        body: Encodable,
        delegate: Anthropic.StreamingDelegate
    ) async throws -> Task<Void, Error> {
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

        log.debug("DEBUG-STREAM: Request URL: \(url)")
        log.debug("DEBUG-STREAM: Request Headers: \(request.allHTTPHeaderFields ?? [:])")

        let task = Task {
            log.debug("DEBUG-STREAM: Starting stream request...")

            let (bytes, response) = try await session.bytes(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                log.error("DEBUG-STREAM: Invalid response - not HTTPURLResponse")
                throw Anthropic.Error.invalidResponse
            }

            log.debug("DEBUG-STREAM: Response Status: \(httpResponse.statusCode)")
            log.debug("DEBUG-STREAM: Response Headers: \(httpResponse.allHeaderFields)")

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

        if let errorString = String(data: errorData, encoding: .utf8) {
            log.error("DEBUG-STREAM: Error response: \(errorString)")
        }

        if let apiError = try? JSONDecoder().decode(Anthropic.APIError.self, from: errorData) {
            throw Anthropic.Error.apiError(apiError)
        } else {
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw Anthropic.Error.unexpectedAPIResponse(errorMessage)
        }
    }

    private func processStreamBytes(bytes: URLSession.AsyncBytes, delegate: Anthropic.StreamingDelegate) async throws {
        var buffer = ""
        var currentEvent: String?
        var currentData: String?

        let decoder = JSONDecoder()

        for try await byte in bytes {
            guard let char = String(bytes: [byte], encoding: .utf8) else {
                continue
            }

            buffer += char

            // Process the buffer when we hit a newline
            if char != "\n" {
                continue
            }

            // Trim the buffer
            let line = buffer.trimmingCharacters(in: .whitespacesAndNewlines)

            // Reset buffer for the next line
            buffer = ""

            if line.isEmpty {
                // Empty line signals the end of an event
                if let eventName = currentEvent, let data = currentData, !data.isEmpty {
                    try await processEvent(eventName: eventName, data: data, delegate: delegate, decoder: decoder)
                }

                // Reset for the next event
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

    private func processEvent(eventName: String, data: String, delegate: Anthropic.StreamingDelegate, decoder: JSONDecoder) async throws {
        guard let jsonData = data.data(using: .utf8) else {
            return
        }

        do {
            switch eventName {
            case "message_start":
                let event = try decoder.decode(Anthropic.MessageStartEvent.self, from: jsonData)
                // Use Task to dispatch to main actor
                Task { @MainActor in
                    await delegate.didReceiveMessageStart(event.message)
                }

            case "content_block_start":
                let event = try decoder.decode(Anthropic.ContentBlockStartEvent.self, from: jsonData)
                Task { @MainActor in
                    await delegate.didReceiveContentBlockStart(
                        index: event.index,
                        contentBlock: event.contentBlock
                    )
                }

            case "content_block_delta":
                let event = try decoder.decode(Anthropic.ContentBlockDeltaEvent.self, from: jsonData)
                Task { @MainActor in
                    await delegate.didReceiveContentBlockDelta(
                        index: event.index,
                        delta: event.delta
                    )
                }

            case "content_block_stop":
                let event = try decoder.decode(Anthropic.ContentBlockStopEvent.self, from: jsonData)
                Task { @MainActor in
                    await delegate.didReceiveContentBlockStop(index: event.index)
                }

            case "message_delta":
                let event = try decoder.decode(Anthropic.MessageDeltaEvent.self, from: jsonData)
                Task { @MainActor in
                    await delegate.didReceiveMessageDelta(
                        stopReason: event.delta.stopReason,
                        stopSequence: event.delta.stopSequence,
                        usage: event.usage
                    )
                }

            case "message_stop":
                Task { @MainActor in
                    await delegate.didReceiveMessageStop()
                }

            case "ping":
                Task { @MainActor in
                    await delegate.didReceivePing()
                }

            case "error":
                try await handleErrorEvent(jsonData: jsonData, delegate: delegate)

            default:
                log.warning("Unknown event type: \(eventName)")
            }
        } catch {
            log.error("DEBUG-STREAM: Error decoding \(eventName) event: \(error)")
        }
    }

    private func handleErrorEvent(jsonData: Data, delegate: Anthropic.StreamingDelegate) async throws {
        if let errorDict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
           let errorObject = errorDict["error"] as? [String: Any],
           let errorType = errorObject["type"] as? String,
           let errorMessage = errorObject["message"] as? String {

            log.error("DEBUG-STREAM: Error event: \(errorType) - \(errorMessage)")

            // Construct APIError from the parsed values.
            let errorDetails = Anthropic.APIError.ErrorDetails(message: errorMessage, type: errorType)
            let apiError = Anthropic.APIError(error: errorDetails)

            Task { @MainActor in
                await delegate.didReceiveError(.apiError(apiError))
            }
        }
    }
}
