import Foundation
import CueCommon

@MainActor
extension MessagesAPI {
    public func streamCreate(
        request: Anthropic.MessageRequest,
        delegate: Anthropic.StreamingDelegate
    ) async throws -> Task<Void, Error> {
        return try await client.stream(
            endpoint: "messages",
            method: "POST",
            body: request,
            delegate: delegate
        )
    }

    public func streamCreate(
        model: String = "claude-3-opus-20240229",
        maxTokens: Int = 1024,
        messages: [Anthropic.ChatMessageParam],
        tools: [JSONValue]? = nil,
        toolChoice: [String: String]? = nil,
        stream: Bool = false,
        thinking: Anthropic.Thinking? = nil,
        delegate: Anthropic.StreamingDelegate
    ) async throws -> Task<Void, Error> {
        let request = Anthropic.MessageRequest(
            model: model,
            maxTokens: maxTokens,
            messages: messages,
            tools: tools,
            toolChoice: toolChoice,
            stream: stream,
            thinking: thinking
        )

        return try await client.stream(
            endpoint: "messages",
            method: "POST",
            body: request,
            delegate: delegate
        )
    }

    public func streamMessage(
        model: String = "claude-3-opus-20240229",
        maxTokens: Int = 1024,
        messages: [Anthropic.ChatMessageParam],
        tools: [JSONValue]? = nil,
        toolChoice: [String: String]? = nil,
        stream: Bool = false,
        thinking: Anthropic.Thinking? = nil
    ) -> AsyncThrowingStream<Anthropic.StreamResponse, Error> {
        let (asyncStream, continuation) = AsyncThrowingStream<Anthropic.StreamResponse, Error>.makeStream()

        let delegate = StreamingDelegateAdapter(continuation: continuation)

        Task {
            do {
                let streamTask = try await streamCreate(
                    model: model,
                    maxTokens: maxTokens,
                    messages: messages,
                    tools: tools,
                    toolChoice: toolChoice,
                    stream: stream,
                    thinking: thinking,
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

    private actor StreamingDelegateAdapter: Anthropic.StreamingDelegate {
        private let continuation: AsyncThrowingStream<Anthropic.StreamResponse, Error>.Continuation

        init(continuation: AsyncThrowingStream<Anthropic.StreamResponse, Error>.Continuation) {
            self.continuation = continuation
        }

        func didReceiveMessageStart(_ message: Anthropic.Message) async {
            let event = Anthropic.MessageStartEvent(type: "message_start", message: message)
            continuation.yield(.messageStart(event))
        }

        func didReceiveContentBlockStart(index: Int, contentBlock: Anthropic.ContentBlockStartEvent.ContentBlockStart) async {
            let event = Anthropic.ContentBlockStartEvent(type: "content_block_start", index: index, contentBlock: contentBlock)
            continuation.yield(.contentBlockStart(event))
        }

        func didReceiveContentBlockDelta(index: Int, delta: Anthropic.ContentBlockDeltaEvent.DeltaContent) async {
            let event = Anthropic.ContentBlockDeltaEvent(type: "content_block_delta", index: index, delta: delta)
            continuation.yield(.contentBlockDelta(event))
        }

        func didReceiveContentBlockStop(index: Int) async {
            let event = Anthropic.ContentBlockStopEvent(type: "content_block_stop", index: index)
            continuation.yield(.contentBlockStop(event))
        }

        func didReceiveMessageDelta(stopReason: String?, stopSequence: String?, usage: Anthropic.Usage) async {
            let delta = Anthropic.MessageDeltaEvent.Delta(stopReason: stopReason, stopSequence: stopSequence)
            let event = Anthropic.MessageDeltaEvent(type: "message_delta", delta: delta, usage: usage)
            continuation.yield(.messageDelta(event))
        }

        func didReceiveMessageStop() async {
            let event = Anthropic.MessageStopEvent(type: "message_stop")
            continuation.yield(.messageStop(event))
        }

        func didReceivePing() async {
            let event = Anthropic.PingEvent(type: "ping")
            continuation.yield(.ping(event))
        }

        func didReceiveError(_ error: Anthropic.Error) async {
            continuation.finish(throwing: error)
        }

        func didCompleteWithError(_ error: Anthropic.Error) async {
            continuation.finish(throwing: error)
        }
    }
}
