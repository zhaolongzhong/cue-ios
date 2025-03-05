//
//  ChatViewDelegate.swift
//  CueApp
//
import SwiftUI
import CueOpenAI

@MainActor
class ChatViewDelegate: RichTextFieldDelegate {
    weak var chatViewModel: (any ChatViewModel)?
    let onPickAttachmentAction: ((_ attachment: Attachment) -> Void)?
    let openLiveChatAction: (() -> Void)?
    let stopAction: (() -> Void)?
    let sendAction: (() -> Void)?
    let reloadProviderSettingsAction: (() -> Void)?

    init(
        chatViewModel: (any ChatViewModel)? = nil,
        onPickAttachment: ((_ attachment: Attachment) -> Void)? = nil,
        openLiveChatAction: (() -> Void)? = nil,
        sendAction: (() -> Void)? = nil,
        stopAction: (() -> Void)? = nil,
        onReloadProviderSettings: (() -> Void)? = nil
    ) {
        self.chatViewModel = chatViewModel
        self.onPickAttachmentAction = onPickAttachment
        self.openLiveChatAction = openLiveChatAction
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

    func onOpenVoiceChat() {
        openLiveChatAction?()
    }

    func onUpdateSelectedCapabilities(_ capabilities: [Capability]) {
        Task {
            await chatViewModel?.updateSelectedCapabilities(capabilities)
        }
    }

    func onShowAXApp(_ app: AccessibleApplication) {
        chatViewModel?.updateObservedApplication(to: app)
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

    func onPickAttachment(_ attachment: Attachment) {
        chatViewModel?.addAttachment(attachment)
        onPickAttachmentAction?(attachment)
    }

    func onReloadProviderSettings() {
        reloadProviderSettingsAction?()
    }
}
