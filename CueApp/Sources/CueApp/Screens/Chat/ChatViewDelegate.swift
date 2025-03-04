//
//  ChatViewDelegate.swift
//  CueApp
//
import SwiftUI

@MainActor
class ChatViewDelegate: RichTextFieldDelegate {
    weak var chatViewModel: (any ChatViewModel)?
    let onPickAttachmentAction: ((_ attachment: Attachment) -> Void)?
    let showToolsAction: (() -> Void)?
    let openLiveChatAction: (() -> Void)?
    let scrollToBottomAction: (() -> Void)?
    let stopAction: (() -> Void)?
    let sendAction: (() -> Void)?
    let reloadProviderSettingsAction: (() -> Void)?

    init(
        chatViewModel: (any ChatViewModel)? = nil,
        onPickAttachment: ((_ attachment: Attachment) -> Void)? = nil,
        showToolsAction: (() -> Void)? = nil,
        openLiveChatAction: (() -> Void)? = nil,
        scrollToBottomAction: (() -> Void)? = nil,
        sendAction: (() -> Void)? = nil,
        stopAction: (() -> Void)? = nil,
        onReloadProviderSettings: (() -> Void)? = nil
    ) {
        self.chatViewModel = chatViewModel
        self.onPickAttachmentAction = onPickAttachment
        self.showToolsAction = showToolsAction
        self.openLiveChatAction = openLiveChatAction
        self.scrollToBottomAction = scrollToBottomAction
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
            scrollToBottomAction?()
        }
    }

    func onShowTools() {
        showToolsAction?()
    }

    func onOpenVoiceChat() {
        openLiveChatAction?()
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

    func onUpdateMessage(_ message: String) {
        chatViewModel?.newMessage = message
    }

    func onReloadProviderSettings() {
        reloadProviderSettingsAction?()
    }
}
