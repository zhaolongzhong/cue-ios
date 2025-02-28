//
//  OpenAIChatViewModel+Stream.swift
//  CueApp
//

import os
import Foundation
import Dependencies
import CueCommon
import CueOpenAI

// Stream event types for OpenAI
public enum OpenAIStreamEvent {
    case streamTaskStarted(String)
    case streamTaskCompleted(String)
    case text(String, String)  // id, text content
    case toolCall(String, [ToolCall])  // id, tool calls
    case toolResult(String, CueChatMessage)  // id, tool result message
    case completed
}

// Stream delegate for OpenAI
@MainActor
class OpenAIStreamingDelegate: OpenAI.StreamingDelegate {
    private let onEvent: (OpenAIStreamEvent) async -> Void
    private let onToolCall: (String, [ToolCall]) async -> [OpenAI.ToolMessage]
    private let toolManager: ToolManager?

    var messageId: String = ""
    var model: String = ""
    private var currentText: String = ""
    // Tool call buildup
    private var currentToolCallId: String = ""
    private var currentFunctionName: String = ""
    private var currentArguments: String = ""
    private var type: String = "function" // always function

    private var observedToolCalls: [ToolCall] = []
    private var toolResultsComplete = false
    private var toolResultsTask: Task<Void, Error>?

    public private(set) var toolResultContents: [OpenAI.ToolMessage] = []
    public private(set) var finalMessage: OpenAI.ChatMessageParam?
    private let logger = Logger(subsystem: "OpenAI", category: "OpenAIStreamingDelegate")

    var hasToolResults: Bool {
        return !toolResultContents.isEmpty
    }

    init(
        toolManager: ToolManager? = nil,
        onEvent: @escaping (OpenAIStreamEvent) async -> Void,
        onToolCall: @escaping (String, [ToolCall]) async -> [OpenAI.ToolMessage]
    ) {
        self.toolManager = toolManager
        self.onEvent = onEvent
        self.onToolCall = onToolCall
    }

    func resetToolCallBuildUp() {
        currentToolCallId = ""
        currentFunctionName = ""
        currentArguments = ""
    }

    func didReceiveStart(id: String, model: String) async {
        self.messageId = id
        self.model = model
        await onEvent(.streamTaskStarted(id))
        currentText = ""
        resetToolCallBuildUp()
        observedToolCalls = []
        toolResultContents = []
        toolResultsTask?.cancel()
        toolResultsTask = nil
        finalMessage = nil
    }

    func didReceiveContent(id: String, delta: String, index: Int) async {
        currentText += delta
        await onEvent(.text(id, delta))
    }

    func didReceiveToolCallDelta(id: String, delta: [OpenAI.ToolCallDelta], index: Int) async {
        for toolCallDelta in delta {
            if let toolCallId = toolCallDelta.id {
                self.currentToolCallId = toolCallId
            }
            if let nameDelta = toolCallDelta.function?.name {
                currentFunctionName += nameDelta
            }
            if let argumentsDelta = toolCallDelta.function?.arguments {
                currentArguments += argumentsDelta
            }
        }
    }

    func didReceiveStop(id: String, finishReason: String?, index: Int) async {
        logger.debug("[\(self.messageId)] Message stop received")
        if finishReason == "tool_calls" {
            // Construct tool call
            let function = Function(name: currentFunctionName, arguments: currentArguments)
            let toolCall = ToolCall(id: currentToolCallId, type: type, function: function)
            if observedToolCalls.first(where: { $0.id == toolCall.id }) == nil {
                observedToolCalls.append(toolCall)
                // Tell the event handler, update ui for tool call
                await onEvent(.toolCall(messageId, observedToolCalls))
            }
            // Build final assistant message with tool call
            finalMessage = OpenAI.ChatMessageParam.assistantMessage(.init(role: "assistant", content: currentText, toolCalls: !observedToolCalls.isEmpty ? observedToolCalls : nil))
            resetToolCallBuildUp()

            // Process any tool calls detected in the message
            if !observedToolCalls.isEmpty {
                // Start a task to process tool calls
                toolResultsTask = Task {
                    await processToolCalls()
                    toolResultsComplete = true
                }
            }
        } else {
            finalMessage = OpenAI.ChatMessageParam.assistantMessage(.init(role: "assistant", content: currentText, toolCalls: nil))
        }
    }

    func didReceiveError(_ error: OpenAI.Error) async {
        print("didReceiveError error: \(error)")
    }

    func didCompleteWithError(_ error: OpenAI.Error) async {
        print("didCompleteWithError error: \(error)")
    }

    // Handle tool calls detected in the content
    private func processToolCalls() async {
        guard observedToolCalls.isEmpty == false else {
            return
        }

        let results = await onToolCall(messageId, observedToolCalls)
        toolResultContents.append(contentsOf: results)
        for toolMessage in results {
            let cueChatMessage = CueChatMessage.openAI(
                .toolMessage(toolMessage),
                stableId: "tool_result_\(toolMessage.toolCallId)"
            )
            // Tell the event handler, update ui for tool result message
            await onEvent(.toolResult(messageId, cueChatMessage))
        }
    }

    // Wait for all tool calls to complete
    func waitForToolResults() async {
        if let task = toolResultsTask {
            try? await task.value
        }
    }

    func hasCompleteToolResults() -> Bool {
        return toolResultsComplete && observedToolCalls.count == toolResultContents.count
    }
}
