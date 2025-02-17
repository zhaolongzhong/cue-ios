import Foundation
import CueOpenAI

extension EmailScreenViewModel {

    private func checkMicrophonePermission() async throws {
        do {
            #if os(macOS)
            // First check if there's any microphone available
            let hasMicrophone = try await AudioPermissionHandler.validateMacOSPermission()
            if !hasMicrophone {
                // No microphone available - set state accordingly without showing permission alert
                self.micPermissionGranted = false
                self.voiceChatState = .error("This device does not have a microphone available")
                return
            }
            #endif

            try await AudioPermissionHandler.checkAndRequestPermission()
            await MainActor.run {
                self.micPermissionGranted = true
            }
        } catch let error as AudioPermissionError {
            let errorMessage: String
            switch error {
            case .denied:
                errorMessage = "Microphone access denied. Please enable it in Settings."
                self.showMicAlert = true
            case .restricted:
                errorMessage = "Microphone access is restricted on this device."
                self.showMicAlert = true
            case .timeout:
                errorMessage = "Timed out while checking microphone access. Please try again."
            case .unknown(let message):
                errorMessage = "Microphone error: \(message)"
            }
            // Update the global processing state with the specific error
            self.micPermissionGranted = false
            self.voiceChatState = .error(errorMessage)
            throw error
        }
    }

    func startVoiceChat() async {
        do {
            guard let apiKey = apiKey else {
                fatalError("Client API key not set")
            }
            micPermissionGranted = true
            // First check microphone permission
            try await checkMicrophonePermission()

            // Only proceed if we have permission
            if micPermissionGranted {
                setupRealtimeSubscription()
                try await realtimeClient.startSession(apiKey: apiKey, model: ChatRealtimeModel.gpt4oRealtimePreview.id)
                voiceChatState = .active
                try await updateSession()
            }
        } catch {
            voiceChatState = .error("Failed to start voice chat: \(error.localizedDescription)")
        }
    }

    func stopVoiceChat() {
        AppLog.log.debug("stopVoiceChat")
        Task {
            await realtimeClient.endChat()
            voiceChatState = .idle
        }
    }

    private func updateSession() async throws {
        var builder = SessionUpdateBuilder()
        builder.instructions =  Instructions.buildVoiceInstruction(name: name)
        builder.tools = self.toolManager.getTools().map { $0.asDefinition() }
        builder.toolChoice = .auto
        let event = ClientEvent.sessionUpdate(
            ClientEvent.SessionUpdateEvent(type: "session.update", session: builder.build())
        )
        do {
            try await realtimeClient.send(event: event)
        } catch {
            self.logger.error("Update session error: \(error)")
            throw error
        }
    }

    private func setupRealtimeSubscription() {
        realtimeClient.voiceChatStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.voiceChatState = state
            }
            .store(in: &cancellables)

        realtimeClient.eventsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] serverEvent in
                guard let self = self else { return }
                switch serverEvent {
                case .error(let errorEvent):
                    self.logger.debug("Received server error: \(errorEvent.error.message)")
                    self.voiceChatState = .error(errorEvent.error.message)
                case .responseAudioTranscriptDelta(let event):
                    self.deltaMessage += event.delta
                case .responseAudioDone:
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.deltaMessage = ""
                    }
                case .responseOutputItemDone(let itemDoneEvent):
                    if self.handledEventIds.contains(itemDoneEvent.eventId) {
                        return
                    }
                    self.handledEventIds.insert(itemDoneEvent.eventId)
                    Task {
                        await self.handleItemDoneEvent(itemDoneEvent)
                    }
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }

    private func handleItemDoneEvent(_ itemDoneEvent: ResponseOutputItemDoneEvent) async {
        switch itemDoneEvent.item.type {
        case .functionCall:
            self.logger.debug("Received itemDoneEvent functionCall: \(String(describing: itemDoneEvent))")
            guard let toolCall = itemDoneEvent.item.asFunctionCall()?.toToolCall() else { return }
            await handleFunctionCall(toolCall: toolCall)
        case .message:
            self.logger.debug("Received itemDoneEvent message: \(String(describing: itemDoneEvent))")
        default:
            break
        }
    }

    private func handleFunctionCall(toolCall: ToolCall) async {
        let toolMessages = await toolManager.callTools([toolCall])
        await createConversationItemWithOutput(toolMessages: toolMessages)
    }

    private func createConversationItemWithOutput(previousItemId: String? = nil, toolMessages: [OpenAI.ToolMessage]) async {
        let toolCallResult = toolMessages[0].getText()
        let toolCallId = toolMessages[0].toolCallId

        let item = ConversationItem(
            id: UUID().uuidString.replacingOccurrences(of: "-", with: ""),
            type: ItemType.functionCallOutput,
            callId: toolCallId,
            output: toolCallResult
        )

        let event = ClientEvent.conversationItemCreate(
            ClientEvent.ConversationItemCreateEvent(
                previousItemId: previousItemId,
                item: item
            )
        )

        do {
            try await realtimeClient.send(event: event)
            try await realtimeClient.createResponse()
        } catch {
            self.logger.error("Send tool result error: \(error)")
        }
    }

    func autoStartVoiceSummarization() async {
        let categoriesContent = getCategorySummaries()
        let summaries = getSummaryContents()
        await sendMessage(message: "Email summarization session starts, categories: \(categoriesContent), summaries: \(summaries)")
    }

    public func sendMessage(message: String) async {
        AppLog.log.debug("Voice - send message: \(message.prefix(200))...")
        await createConversationItem(text: message)
    }

    private func createConversationItem(text: String) async {
        let item = ConversationItem(
            id: UUID().uuidString.replacingOccurrences(of: "-", with: ""),
            type: .message,
            role: .user,
            content: [
                ContentPart(type: .inputText, text: text)
            ]
        )

        let event = ClientEvent.conversationItemCreate(
            ClientEvent.ConversationItemCreateEvent(
                previousItemId: nil,
                item: item
            )
        )

        do {
            try await realtimeClient.send(event: event)
            try await realtimeClient.createResponse()
        } catch {
            self.logger.error("Send message error: \(error)")
        }
    }

    private func getCategorySummaries() -> String {
        let categoryCounts = Dictionary(grouping: emailSummaries) { $0.category }
            .mapValues { $0.count }

        let summaries = EmailCategory.allCases.map { category in
            "\(category.displayName): \(categoryCounts[category, default: 0])"
        }
        return summaries.joined(separator: "\n")
    }

    private func getSummaryContents() -> String {
        let summaries = emailSummaries.map {
            "\($0.conciseSummary), "
        }
        return summaries.joined(separator: "\n")
    }
}

extension EmailSummary {
    var conciseSummary: String {
        var summary = """
ID: \(self.id)
Thread_ID: \(self.thread)
Subject: \(self.title)
Snippet: \(self.snippet)
Category: \(self.category)
"""

        if let from = self.originalEmail?.from {
            summary += "\nFrom: \(from)"
        }

        summary += "\nDate: \(self.date)"

        if let labelIds = self.originalEmail?.labelIds {
            summary += "\nLabelIds: \(labelIds.joined(separator: ", "))"
        }
        return summary
    }
}
