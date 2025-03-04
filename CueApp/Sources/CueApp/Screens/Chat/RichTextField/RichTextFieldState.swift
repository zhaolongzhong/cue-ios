//
//  RichTextFieldState.swift
//  CueApp
//

import SwiftUI

class RichTextFieldState: ObservableObject {
    @Published var inputMessage: String = ""
    @Published var attachments: [Attachment]
    @Published var isTextFieldVisible: Bool = false
    @Published var isRunning: Bool = false
    @Published var isEnabled: Bool = true
    @Published var showVoiceChat: Bool = false
    @Published var showAXApp: Bool = false
    @Published var toolCount: Int = 0

    var isMessageValid: Bool {
        inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).count >= 1
    }

    init(
        inputMessage: String = "",
        attachments: [Attachment] = [],
        isTextFieldVisible: Bool = false,
        isRunning: Bool = false,
        isEnabled: Bool = true,
        showVoiceChat: Bool = false,
        showAXApp: Bool = false,
        toolCount: Int = 0
    ) {
        self.inputMessage = inputMessage
        self.attachments = attachments
        self.isTextFieldVisible = isTextFieldVisible
        self.isRunning = isRunning
        self.isEnabled = isEnabled
        self.showVoiceChat = showVoiceChat
        self.showAXApp = showAXApp
        self.toolCount = toolCount
    }
}
