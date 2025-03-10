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
    let availableCapabilities: [Capability]
    let selectedCapabilities: [Capability]
    let observedApp: AccessibleApplication?
    let textAreaContents: [TextAreaContent]

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
        availableCapabilities: [Capability] = [],
        selectedCapabilities: [Capability] = [],
        observedApp: AccessibleApplication? = nil,
        textAreaContents: [TextAreaContent] = []
    ) {
        self.conversationId = conversationId
        self.inputMessage = inputMessage
        self.attachments = attachments
        self.isTextFieldVisible = isTextFieldVisible
        self.isRunning = isRunning
        self.isEnabled = isEnabled
        self.showVoiceChat = showVoiceChat
        self.showAXApp = showAXApp
        self.availableCapabilities = availableCapabilities
        self.selectedCapabilities = selectedCapabilities
        self.observedApp = observedApp
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
        availableCapabilities: [Capability]? = nil,
        selectedCapabilities: [Capability]? = nil,
        observedApp: AccessibleApplication? = nil,
        textAreaContents: [TextAreaContent]? = nil,
        clearObservedApp: Bool = false
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
            availableCapabilities: availableCapabilities ?? self.availableCapabilities,
            selectedCapabilities: selectedCapabilities ?? self.selectedCapabilities,
            observedApp: clearObservedApp ? nil : (observedApp ?? self.observedApp),
            textAreaContents: clearObservedApp ? [] : (textAreaContents ?? self.textAreaContents)
        )
    }
}
