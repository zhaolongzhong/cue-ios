//
//  OpenAI+ CompletionsAPI.swift
//  CueOpenAI
//

import Foundation
import CueCommon

@MainActor
extension CompletionsAPI {
    public func streamCreate(
        request: OpenAI.ChatCompletionRequest,
        delegate: OpenAI.StreamingDelegate
    ) async throws -> Task<Void, Error> {
        return try await client.stream(
            endpoint: "chat/completions",
            method: "POST",
            body: request,
            delegate: delegate
        )
    }

    public func streamCreate(
        model: String = "gpt-4o-mini",
        maxTokens: Int = 1024,
        temperature: Double = 1.0,
        messages: [OpenAI.ChatMessageParam],
        tools: [JSONValue]? = nil,
        toolChoice: String? = nil,
        delegate: OpenAI.StreamingDelegate
    ) async throws -> Task<Void, Error> {
        let request = OpenAI.ChatCompletionRequest(
            model: model,
            messages: messages,
            maxTokens: maxTokens,
            temperature: temperature,
            tools: tools,
            toolChoice: toolChoice,
            stream: true
        )

        return try await client.stream(
            endpoint: "chat/completions",
            method: "POST",
            body: request,
            delegate: delegate
        )
    }

    public func streamChat(
        model: String = "gpt-4o-mini",
        maxTokens: Int = 1024,
        temperature: Double = 1.0,
        messages: [OpenAI.ChatMessageParam],
        tools: [JSONValue]? = nil,
        toolChoice: String? = nil
    ) -> AsyncThrowingStream<OpenAI.ChatCompletionChunk, Error> {
        let (asyncStream, continuation) = AsyncThrowingStream<OpenAI.ChatCompletionChunk, Error>.makeStream()

        let delegate = StreamingDelegateAdapter(continuation: continuation)

        Task {
            do {
                let streamTask = try await streamCreate(
                    model: model,
                    maxTokens: maxTokens,
                    temperature: temperature,
                    messages: messages,
                    tools: tools,
                    toolChoice: toolChoice,
                    delegate: delegate
                )

                try await streamTask.value
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }

        return asyncStream
    }

    private actor StreamingDelegateAdapter: OpenAI.StreamingDelegate {
        private let continuation: AsyncThrowingStream<OpenAI.ChatCompletionChunk, Error>.Continuation
        private var currentChunk: OpenAI.ChatCompletionChunk?
        private var currentChunks: [OpenAI.ChatCompletionChunk] = []
        private var contentBuffers: [Int: String] = [:]

        init(continuation: AsyncThrowingStream<OpenAI.ChatCompletionChunk, Error>.Continuation) {
            self.continuation = continuation
        }

        func didReceiveStart(id: String, model: String) async {
            let choice = OpenAI.ChunkChoice(
                index: 0,
                delta: OpenAI.DeltaContent(role: "assistant", content: "", toolCalls: nil ),
                logprobs: nil,
                finishReason: nil
            )

            let chunk = OpenAI.ChatCompletionChunk(
                id: id,
                object: "chat.completion.chunk",
                created: Int(Date().timeIntervalSince1970),
                model: model,
                systemFingerprint: nil,
                choices: [choice], usage: nil
            )

            currentChunk = chunk
            continuation.yield(chunk)
        }

        func didReceiveContent(id: String, delta: String, index: Int) async {
            // Get or initialize the content buffer for this index
            let currentContent = contentBuffers[index, default: ""]
            contentBuffers[index] = currentContent + delta

            // Create a new chunk with the delta
            let choice = OpenAI.ChunkChoice(
                index: index,
                delta: OpenAI.DeltaContent(role: nil, content: delta, toolCalls: nil),
                logprobs: nil,
                finishReason: nil
            )

            let chunk = currentChunk ?? OpenAI.ChatCompletionChunk(
                id: id,
                object: "chat.completion.chunk",
                created: Int(Date().timeIntervalSince1970),
                model: "unknown",
                systemFingerprint: nil,
                choices: [choice],
                usage: nil
            )

            currentChunks.append(chunk)
            continuation.yield(chunk)
        }

        func didReceiveToolCallDelta(id: String, delta: [OpenAI.ToolCallDelta], index: Int) async {
            print("completion api - didReceiveToolCallDelta")
        }

        func didReceiveStop(id: String, finishReason: String?, index: Int) async {
            let choice = OpenAI.ChunkChoice(
                index: index,
                delta: OpenAI.DeltaContent(role: nil, content: nil, toolCalls: nil),
                logprobs: nil,
                finishReason: finishReason
            )

            let chunk = OpenAI.ChatCompletionChunk(
                id: id,
                object: "chat.completion.chunk",
                created: Int(Date().timeIntervalSince1970),
                model: "gpt-4o-mini",
                systemFingerprint: nil,
                choices: [choice],
                usage: nil
            )
            currentChunks.append(chunk)
            continuation.yield(chunk)
        }

        func didReceiveError(_ error: OpenAI.Error) async {

        }

        func didCompleteWithError(_ error: OpenAI.Error) async {

        }
    }
}
