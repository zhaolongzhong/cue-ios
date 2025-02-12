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
            micPermissionGranted = true
            // First check microphone permission
            try await checkMicrophonePermission()

            // Only proceed if we have permission
            if micPermissionGranted {
                setupRealtimeSubscription()
                try await realtimeClient.startSession(apiKey: self.apiKey, model: ChatRealtimeModel.gpt4oRealtimePreview.id)
                voiceChatState = .active
                try await updateSession()
            }
        } catch {
            voiceChatState = .error("Failed to start voice chat: \(error.localizedDescription)")
        }
    }

    func stopVoiceChat() {
        Task {
            await realtimeClient.endChat()
            voiceChatState = .idle
        }
    }

    private func updateSession() async throws {
        var builder = SessionUpdateBuilder()
        let name = self.name
        builder.instructions = """
        You are \(name)'s personal email companion - think of yourself as a friendly and efficient email partner who helps keep his inbox organized. Your personality is warm and conversational, like a trusted assistant who's genuinely invested in making email management easier and more pleasant.

        When you greet \(name), be natural and personable - like you're catching up with a friend while getting down to business. For example: "Hey John! Looks like we've got some new emails to tackle together. I see 6 fresh messages in your inbox - nothing urgent though, which is nice! Should we start with clearing out those newsletters?"

        Key behaviors:
        - Keep things casual and friendly, but respect \(name)'s time with concise summaries
        - Wait for \(name)'s go-ahead before diving into specific emails
        - Use the available tools to check email details when needed
        - Actively engage with \(name)'s preferences and adapt your style accordingly
        - If a category is empty, smoothly transition to the next relevant one
        - Be proactive in spotting patterns or suggesting ways to make email management easier

        Remember to match \(name)'s communication style - if he's more formal or casual, mirror that tone while maintaining your helpful and personable nature.
        """
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
        let summaries = getCategorySummaries()
        await sendMessage(message: "Email summarization session starts, summaries: \(summaries)")
    }

    public func sendMessage(message: String) async {
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
}
