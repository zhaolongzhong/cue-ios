//
//  RichTextFieldState.swift
//  CueApp
//

import SwiftUI
import CueOpenAI

struct RichTextFieldState {
    let conversationId: String?
    let inputMessage: String
    let attachments: [Attachment]
    let isTextFieldVisible: Bool
    let isRunning: Bool
    let isEnabled: Bool
    let showVoiceChat: Bool
    let showAXApp: Bool
    let showToolIcon: Bool
    let availableCapabilities: [Capability]
    let selectedCapabilities: [Capability]
    let workingApps: [String: AccessibleApplication]
    let textAreaContents: [String: TextAreaContent]

    var isMessageValid: Bool {
        inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).count >= 1 || attachments.count > 0 || textAreaContents.count > 0
    }

    init(
        conversationId: String? = nil,
        inputMessage: String = "",
        attachments: [Attachment] = [],
        isTextFieldVisible: Bool = false,
        isRunning: Bool = false,
        isEnabled: Bool = true,
        showVoiceChat: Bool = false,
        showAXApp: Bool = false,
        showToolIcon: Bool = true,
        availableCapabilities: [Capability] = [],
        selectedCapabilities: [Capability] = [],
        workingApps: [String: AccessibleApplication] = [:],
        textAreaContents: [String: TextAreaContent] = [:]
    ) {
        self.conversationId = conversationId
        self.inputMessage = inputMessage
        self.attachments = attachments
        self.isTextFieldVisible = isTextFieldVisible
        self.isRunning = isRunning
        self.isEnabled = isEnabled
        self.showVoiceChat = showVoiceChat
        self.showAXApp = showAXApp
        self.showToolIcon = showToolIcon
        self.availableCapabilities = availableCapabilities
        self.selectedCapabilities = selectedCapabilities
        self.workingApps = workingApps
        self.textAreaContents = textAreaContents

    }

    /// Creates a new instance with optional parameter overrides while preserving existing values
    func copy(
        conversationId: String? = nil,
        inputMessage: String? = nil,
        attachments: [Attachment]? = nil,
        isTextFieldVisible: Bool? = nil,
        isRunning: Bool? = nil,
        isEnabled: Bool? = nil,
        showVoiceChat: Bool? = nil,
        showAXApp: Bool? = nil,
        showToolIcon: Bool? = nil,
        availableCapabilities: [Capability]? = nil,
        selectedCapabilities: [Capability]? = nil,
        workingApps: [String: AccessibleApplication]? = nil,
        textAreaContents: [String: TextAreaContent]? = nil
    ) -> RichTextFieldState {
        return RichTextFieldState(
            conversationId: conversationId ?? self.conversationId,
            inputMessage: inputMessage ?? self.inputMessage,
            attachments: attachments ?? self.attachments,
            isTextFieldVisible: isTextFieldVisible ?? self.isTextFieldVisible,
            isRunning: isRunning ?? self.isRunning,
            isEnabled: isEnabled ?? self.isEnabled,
            showVoiceChat: showVoiceChat ?? self.showVoiceChat,
            showAXApp: showAXApp ?? self.showAXApp,
            showToolIcon: showToolIcon ?? self.showToolIcon,
            availableCapabilities: availableCapabilities ?? self.availableCapabilities,
            selectedCapabilities: selectedCapabilities ?? self.selectedCapabilities,
            workingApps: workingApps ?? self.workingApps,
            textAreaContents: textAreaContents ?? self.textAreaContents
        )
    }
}
