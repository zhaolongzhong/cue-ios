//
//  ChatViewModelProtocol.swift
//  CueApp
//
import SwiftUI
import CueOpenAI

// MARK: - Chat View Model Protocol
@MainActor
protocol ChatViewModelProtocol: ObservableObject, RichTextFieldDelegate {
    var attachments: [Attachment] { get set }
    var cueChatMessages: [CueChatMessage] { get set }
    var isLoadingMore: Bool { get set }
    var richTextFieldState: RichTextFieldState { get set }
    var error: ChatError? { get }
    var observedApp: AccessibleApplication? { get }
    var focusedLines: String? { get }
    var selectedConversationId: String? { get set }
    var availableCapabilities: [Capability] { get }
    var selectedCapabilities: [Capability] { get }
    var model: ChatModel { get set }
    var isStreamingEnabled: Bool { get set }
    var isToolEnabled: Bool { get set }
    var showLiveChat: Bool { get set }

    func startServer() async
    func updateSelectedCapabilities(_ capabilities: [Capability]) async
    func updateObservedApplication(to app: AccessibleApplication?)
    func stopObserveApp()
    func addAttachment(_ attachment: Attachment)
    func sendMessage() async
    func stopAction() async
    func deleteMessage(_ message: CueChatMessage) async
    func clearError()
}

// MARK: - Default implementations of RichTextFieldDelegate for ChatViewModel
extension ChatViewModelProtocol {

    func onSend() {
        Task {
            await sendMessage()
        }
    }

    func onStop() {
        Task {
            await stopAction()
        }
    }

    func onAddAttachment(_ attachment: Attachment) {
        // Update the immutable state
        richTextFieldState = richTextFieldState.copy(
            attachments: richTextFieldState.attachments + [attachment]
        )

        // Also update the attachments array used by ChatViewModel protocol
        addAttachment(attachment)
    }

    func onRemoveAttachment(at index: Int) {
        // Update the immutable state
        let newAttachments = richTextFieldState.attachments.enumerated()
            .filter { $0.offset != index }
            .map { $0.element }

        richTextFieldState = richTextFieldState.copy(attachments: newAttachments)

        // Also update the attachments array
        attachments = newAttachments
    }

    func onClearAttachments() {
        richTextFieldState = richTextFieldState.copy(attachments: [])
        attachments.removeAll()
    }

    func onUpdateInputMessage(_ message: String) {
        richTextFieldState = richTextFieldState.copy(inputMessage: message)
    }

    func onUpdateSelectedCapabilities(_ capabilities: [Capability]) {
        Task {
            await updateSelectedCapabilities(capabilities)
        }
    }

    func onOpenVoiceChat() {
        showLiveChat = true
    }

    func onShowAXApp(to app: AccessibleApplication) {
        self.updateObservedApplication(to: app)
    }
}

@MainActor
class ChatViewDelegate: RichTextFieldDelegate {
    weak var chatViewModel: (any ChatViewModelProtocol)?
    let stopAction: (() -> Void)?
    let sendAction: (() -> Void)?
    let reloadProviderSettingsAction: (() -> Void)?

    init(
        chatViewModel: (any ChatViewModelProtocol)? = nil,
        onPickAttachment: ((_ attachment: Attachment) -> Void)? = nil,
        openLiveChatAction: (() -> Void)? = nil,
        sendAction: (() -> Void)? = nil,
        stopAction: (() -> Void)? = nil,
        onReloadProviderSettings: (() -> Void)? = nil
    ) {
        self.chatViewModel = chatViewModel
        self.sendAction = sendAction
        self.stopAction = stopAction
        self.reloadProviderSettingsAction = onReloadProviderSettings
    }

    func onSend() {
        guard let chatViewModel = chatViewModel else {
            sendAction?()
            return
        }

        Task {
            await chatViewModel.sendMessage()
        }
    }

    func onStop() {
        guard let chatViewModel = chatViewModel else {
            stopAction?()
            return
        }

        Task {
            await chatViewModel.stopAction()
        }
    }

    func onAddAttachment(_ attachment: Attachment) {
        chatViewModel?.addAttachment(attachment)
    }

    func onRemoveAttachment(at index: Int) {
        chatViewModel?.onRemoveAttachment(at: index)
    }

    func onClearAttachments() {
        chatViewModel?.onClearAttachments()
    }

    func onUpdateInputMessage(_ message: String) {
        chatViewModel?.onUpdateInputMessage(message)
    }

    func onUpdateSelectedCapabilities(_ capabilities: [Capability]) {
        Task {
            await chatViewModel?.updateSelectedCapabilities(capabilities)
        }
    }

    func onOpenVoiceChat() {
        if let chatViewModel = chatViewModel {
            chatViewModel.onOpenVoiceChat()
        }
    }

    func onShowAXApp(to app: AccessibleApplication) {
        chatViewModel?.updateObservedApplication(to: app)
    }

    func onReloadProviderSettings() {
        reloadProviderSettingsAction?()
    }
}
