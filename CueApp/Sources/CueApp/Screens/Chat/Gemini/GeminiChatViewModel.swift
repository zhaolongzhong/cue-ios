//
//  GeminiChatViewModel.swift
//  CueApp
//

import os
import Foundation
import CueCommon
import CueGemini
import CueOpenAI

public struct ScreenSharingState {
    var isEnabled: Bool
    var isScreenSharing: Bool

    public init(isEnabled: Bool = false, isScreenSharing: Bool = false) {
        self.isEnabled = isEnabled
        self.isScreenSharing = isScreenSharing
    }
}

@MainActor
public class GeminiChatViewModel: BaseChatViewModel {
    @Published var screenSharingState: ScreenSharingState = .init(isEnabled: true)
    @Published var showPermissionAlert: Bool = false
    @Published var isSpeaking = false
    @Published var state: VoiceState = .idle {
        didSet {
            logger.debug("Voice state change to \(self.state.description)")
            switch state {
            case .error(let message):
                error = .sessionError(message)
            default:
                break
            }
        }
    }

    private let gemini: Gemini
    var geminiTool: GeminiTool?
    let liveAPIClient: LiveAPIClient
    let logger = Logger(subsystem: "Gemini", category: "Gemini")
    var screenCaptureManager: ScreenCaptureManager
    var screenCaptureTask: Task<Void, Never>?

    public init(conversationId: String?, apiKey: String) {
        self.gemini = Gemini(apiKey: apiKey)
        self.liveAPIClient = LiveAPIClient()
        self.state = liveAPIClient.voiceChatState
        self.screenCaptureManager = ScreenCaptureManager()

        super.init(
            apiKey: apiKey,
            provider: .gemini,
            model: .gemini20FlashExp,
            conversationId: conversationId,
            richTextFieldState: RichTextFieldState(showVoiceChat: true, showAXApp: true)
        )

        setupLiveAPISubscription()
    }

    override func updateTools() {
        super.updateTools()
        self.geminiTool = toolManager.getGeminiTool()
    }

    public func generateContent() async throws {
        do {
            let messageParams = Array(self.cueChatMessages.suffix(maxMessages))
            let geminiChatParams = messageParams.compactMap { $0.geminiChatParam?.modelContent }

            let tools: [GeminiTool] = geminiTool == nil ? [] : [geminiTool!]

            let response = try await gemini.chat.generateContent(
                model: model.id,
                messages: geminiChatParams,
                tools: tools.isEmpty ? nil : tools
            )
            AppLog.log.debug("Generate content response: \(String(describing: response.candidates[0]))")
            let candidateContent = response.candidates[0].content
            let newMessage = CueChatMessage.gemini(Gemini.ChatMessageParam.assistantMessage(candidateContent), stableId: UUID().uuidString)
            addOrUpdateMessage(newMessage, persistInCache: true)

            for part in candidateContent.parts {
                if case .functionCall(let functionCall) = part {
                    try await handleFunctionCallAndRecursivelyGenerate(functionCall)
                }
                // The text parts are already included in the message we added
            }
        } catch let error as Gemini.Error {
            handleError(error)
        } catch {
            self.error = .sessionError("An unexpected error occurred: \(error.localizedDescription)")
            AppLog.log.error("Generate content error: \(error)")
        }
    }

    private func handleFunctionCallAndRecursivelyGenerate(_ functionCall: GeminiFunctionCall) async throws {
        AppLog.log.debug("Handling function call: \(String(describing: functionCall))")
        let result = await handleFunctionCall(functionCall)
        let functionResponse = ModelContent(
            role: "user",
            parts: [.functionResponse(FunctionResponse(
                id: functionCall.id,
                name: functionCall.name,
                response: [
                    "name": .string(functionCall.name),
                    "content": .string(result)
                ]
            ))]
        )
        let newMessage = CueChatMessage.gemini(Gemini.ChatMessageParam.toolMessage(functionResponse), stableId: UUID().uuidString)
        addOrUpdateMessage(newMessage, persistInCache: true)
        try await generateContent()
    }

    private func handleError(_ error: Error) {
        var errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
        guard let geminiError = error as? Gemini.Error else {
            self.error = .sessionError(errorMessage)
            AppLog.log.error("Generate content error: \(error)")
            return
        }

        switch geminiError {
        case .apiError(let apiError):
            let message = apiError.error.message

            if message.contains("key expired") || message.contains("key not valid") {
                errorMessage = "Your API key is invalid or has expired. Please renew your API key to continue."
                break
            }
            let detailMessage = apiError.error.details.first { $0.message != nil }?.message ?? message
            errorMessage = "Error: \(detailMessage)"

        case .unexpectedAPIResponse(let message):
            if message.contains("key expired") {
                errorMessage = "Your API key has expired. Please renew your API key to continue."
                break
            }

            errorMessage = "An error occurred while generating content: \(message)"
        default:
            break
        }

        self.error = .sessionError(errorMessage)
        AppLog.log.error("Generate content error: \(error)")
    }

    override func sendMessage() async {
        do {
            if !self.state.isConnected {
                try await sendMessageWithAsyncClient()
            } else {
                try await sendLiveMessage()
            }
        } catch {
            self.error = .sessionError(error.localizedDescription)
        }
    }

    public func sendMessageWithAsyncClient() async throws {
        guard richTextFieldState.isMessageValid else { return }
        let (userMessage, _) = await prepareGeminiMessage()
        AppLog.log.debug("Send message with async client. New message: \(self.richTextFieldState.inputMessage)")
        addOrUpdateMessage(.gemini(userMessage, stableId: UUID().uuidString), persistInCache: true)
        richTextFieldState.inputMessage = ""
        try await generateContent()
    }

    private func sendLiveMessage() async throws {
        do {
            AppLog.log.debug("Send live message with attachments: \(self.attachments.count)")
            let imageDataList = attachments.compactMap { attachment in
                return attachment.imageData
            }
            cleanupAttachments()
            for data in imageDataList {
                let realtimeInput = ClientMessage.makeRealtimeInputMessage(
                    mimeType: .imageJpeg,
                    data: data.base64EncodedString()
                )
                try await self.liveAPIClient.send(realtimeInput)
            }
            let newMessage = richTextFieldState.inputMessage
            if !newMessage.isEmpty {
                try await sendLiveText(newMessage)
            }
        } catch {
            self.error = .sessionError(error.localizedDescription)
        }
    }

    private func sendLiveText(_ text: String = "") async throws {
        let part = ModelContent.Part.text(text)
        AppLog.log.debug("Send live text: \(text)")
        try await sendLiveText([part])
        richTextFieldState.inputMessage = ""
    }

    func interrupt() async {
        AppLog.log.debug("Interrupt")
        let part = ModelContent.Part.text("Sorry, I have to interrupt you.")
        do {
            try await sendLiveText([part])
        } catch {
            AppLog.log.debug("Interrupt error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Screen Capture
extension GeminiChatViewModel {
    func startScreenCapture() async {
        AppLog.log.debug("Start screen capture")
        guard !screenSharingState.isScreenSharing else {
            return
        }

        let isAvailable = await screenCaptureManager.requestPermission()
        if !isAvailable {
            showPermissionAlert = true
            return
        }

        do {
            try await screenCaptureManager.startCapturing()
        } catch {
            self.error = ChatError.sessionError("Failed to start screen capture")
        }
        screenSharingState.isScreenSharing = true

        // Start processing frames from the stream
        createScreenCaptureTask()
    }

    public func createScreenCaptureTask() {
        screenCaptureTask?.cancel()
        screenCaptureTask = Task {
            guard let frameStream = screenCaptureManager.events else {
                return
            }
            screenSharingState.isScreenSharing = true
            do {
                for try await frameData in frameStream {
                    let base64Data = frameData.base64EncodedString()
                    let chunk = BidiGenerateContentRealtimeInput.RealtimeInput.MediaChunk(
                        mimeType: .imageJpeg,
                        data: base64Data
                    )
                    let input = BidiGenerateContentRealtimeInput(realtimeInput: .init(mediaChunks: [chunk]))
                    do {
                        try await self.liveAPIClient.send(input)
                    } catch {
                        self.logger.error("Failed to send screen frame: \(error.localizedDescription)")
                    }
                }
            } catch {
                self.logger.error("Screen capture error: \(error)")
            }
        }
    }

    func stopScreenCapture() async {
        AppLog.log.debug("Stop screen capture")
        guard screenSharingState.isScreenSharing else { return }

        screenCaptureTask?.cancel()
        screenCaptureTask = nil

        await screenCaptureManager.stopCapturing()
        screenSharingState.isScreenSharing = false
    }
}
