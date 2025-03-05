//
//  RichTextFieldState.swift
//  CueApp
//

import SwiftUI
import CueOpenAI

class RichTextFieldState: ObservableObject {
    @Published var inputMessage: String = ""
    @Published var attachments: [Attachment]
    @Published var isTextFieldVisible: Bool = false
    @Published var isRunning: Bool = false
    @Published var isEnabled: Bool = true
    @Published var showVoiceChat: Bool = false
    @Published var showAXApp: Bool = false
    @Published var availableCapabilities: [Capability] = []
    @Published var selectedCapabilities: [Capability] = []

    var isMessageValid: Bool {
        inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).count >= 1 || attachments.count > 0
    }

    init(
        inputMessage: String = "",
        attachments: [Attachment] = [],
        isTextFieldVisible: Bool = false,
        isRunning: Bool = false,
        isEnabled: Bool = true,
        showVoiceChat: Bool = false,
        showAXApp: Bool = false,
        availableCapabilities: [Capability] = [],
        selectedCapabilities: [Capability] = []
    ) {
        self.inputMessage = inputMessage
        self.attachments = attachments
        self.isTextFieldVisible = isTextFieldVisible
        self.isRunning = isRunning
        self.isEnabled = isEnabled
        self.showVoiceChat = showVoiceChat
        self.showAXApp = showAXApp
        self.availableCapabilities = availableCapabilities
        self.selectedCapabilities = selectedCapabilities
    }
}
