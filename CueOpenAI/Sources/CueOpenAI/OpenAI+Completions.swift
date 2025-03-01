//
//  OpenAI+ CompletionsI.swift
//  CueOpenAI
//

import Foundation
import CueCommon

@MainActor
public struct Completions {
    let client: OpenAIHTTPClient

    init(client: OpenAIHTTPClient) {
        self.client = client
    }

    public func create(
        model: String,
        messages: [OpenAI.ChatMessageParam],
        maxTokens: Int = 1000,
        temperature: Double = 1.0,
        tools: [JSONValue]? = nil,
        toolChoice: String? = nil
    ) async throws -> OpenAI.ChatCompletion {
        let request = OpenAI.ChatCompletionRequest(
            model: model,
            messages: messages,
            maxTokens: maxTokens,
            temperature: temperature,
            tools: tools,
            toolChoice: toolChoice
        )

        return try await client.send(
            endpoint: "chat/completions",
            method: "POST",
            body: request
        )
    }

    public func createStream(
        request: OpenAI.ChatCompletionRequest
    )  -> (
        events: AsyncThrowingStream<ServerStreamingEvent, Error>,
        connectionState: AsyncStream<ServerStreamingEvent.ConnectionState>,
        cancel: () -> Void
    ) {
        return client.stream(
            endpoint: "chat/completions",
            method: "POST",
            body: request
        )
    }

    public func createStream(
        model: String = "gpt-4o-mini",
        reasoningEffort: String = "medium",
        maxTokens: Int = 1024,
        temperature: Double = 1.0,
        messages: [OpenAI.ChatMessageParam],
        tools: [JSONValue]? = nil,
        toolChoice: String? = nil
    ) -> (
        events: AsyncThrowingStream<ServerStreamingEvent, Error>,
        connectionState: AsyncStream<ServerStreamingEvent.ConnectionState>,
        cancel: () -> Void
    ) {
        let requestBody = OpenAI.ChatCompletionRequest(
            model: model,
            messages: messages,
            maxTokens: maxTokens,
            temperature: temperature,
            tools: tools,
            toolChoice: toolChoice,
            stream: true
        )

        return client.stream(
            endpoint: "chat/completions",
            method: "POST",
            body: requestBody
        )
    }
}
